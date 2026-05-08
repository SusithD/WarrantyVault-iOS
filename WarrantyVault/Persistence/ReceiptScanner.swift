import Foundation
import UIKit
@preconcurrency import Vision

/// Output of a Vision OCR pass over a receipt image. All structured fields
/// are best-effort — `nil` means the parser couldn't isolate that field
/// with enough confidence. `rawText` is always populated so the caller can
/// inspect or display the source text.
struct ReceiptScanResult {
    var rawText: String
    var productName: String?
    var retailer: String?
    var purchaseDate: Date?
    var totalPrice: Double?

    static let empty = ReceiptScanResult(rawText: "")
}

/// On-device Vision OCR with heuristic parsers for retailer/total/date/product.
///
/// Design notes:
///  - Each parser scores *every* candidate and picks the best one rather than
///    taking the first plausible match. That avoids the classic OCR pitfall
///    where boilerplate ("THANK YOU FOR SHOPPING") wins because it appears
///    earlier or is longer than the real answer.
///  - Negative signals matter as much as positive ones — phone-like lines,
///    address-like lines, and exclusion keywords ("subtotal", "cash tendered",
///    "change due") are explicitly demoted, not just deprioritised.
///  - A `parse(text:)` test seam runs the same pipeline on already-OCR'd text
///    so the heuristics are unit-testable without image fixtures.
final class ReceiptScanner {

    static let shared = ReceiptScanner()

    enum Failure: Error {
        case noCGImage
        case underlying(Error)
    }

    /// Run OCR on `image`, then parse the recognised lines into structured fields.
    func scan(_ image: UIImage) async throws -> ReceiptScanResult {
        guard let cg = image.downscaledCGImage(maxDimension: 2000) else {
            throw Failure.noCGImage
        }

        let lines = try await recognizeText(in: cg)
        let rawText = lines.map(\.text).joined(separator: "\n")

        return ReceiptScanResult(
            rawText: rawText,
            productName: parseProductName(from: lines),
            retailer:    parseRetailer(from: lines),
            purchaseDate: parseDate(from: lines),
            totalPrice:  parseTotalPrice(from: lines)
        )
    }

    /// Test seam — runs the heuristic parsers over already-OCR'd text so unit
    /// tests don't need to spin up Vision. Each non-empty line becomes a
    /// `Line` with synthesised high confidence (0.95) so the parsers see the
    /// same shape they would in a real scan.
    func parse(text: String) -> ReceiptScanResult {
        let lines: [Line] = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { idx, raw in
                Line(text: cleanText(String(raw)),
                     confidence: 0.95,
                     index: idx,
                     boundingBox: nil)
            }

        return ReceiptScanResult(
            rawText: text,
            productName: parseProductName(from: lines),
            retailer:    parseRetailer(from: lines),
            purchaseDate: parseDate(from: lines),
            totalPrice:  parseTotalPrice(from: lines)
        )
    }

    // MARK: - Vision

    /// One line of recognised text plus its confidence, position in the
    /// receipt (0-indexed from the top), and — when available — its
    /// bounding box in normalised Vision coordinates (origin bottom-left,
    /// y=0 at the bottom of the image, y=1 at the top). The `parse(text:)`
    /// test seam can't supply geometry so this stays optional; layout-aware
    /// heuristics fall back to keyword-only behaviour when it's nil.
    private struct Line {
        let text: String
        let confidence: Float
        let index: Int
        let boundingBox: CGRect?
    }

    private func recognizeText(in cgImage: CGImage) async throws -> [Line] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    cont.resume(throwing: Failure.underlying(error))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [Line] = observations.enumerated().compactMap { idx, obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let cleaned = self.cleanText(candidate.string)
                    guard !cleaned.isEmpty else { return nil }
                    return Line(text: cleaned,
                                confidence: candidate.confidence,
                                index: idx,
                                boundingBox: obs.boundingBox)
                }
                cont.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: Failure.underlying(error))
                }
            }
        }
    }

    // MARK: - Pre-cleaning

    /// Normalise whitespace, strip control characters, and trim ends.
    /// OCR output frequently contains stray tabs, NBSPs, and zero-width
    /// characters that throw off regex matching.
    private func cleanText(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace any whitespace run (incl. tabs / NBSP) with a single space.
        let collapsed = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // Strip control characters.
        let filtered = collapsed.unicodeScalars.filter {
            !($0.value < 0x20 || $0.value == 0x7F)
        }
        return String(String.UnicodeScalarView(filtered))
    }

    // MARK: - Shared classifiers

    /// Phone-like lines have many digits in close proximity, often with
    /// punctuation. Receipts always print these near the brand header.
    private func isPhoneLine(_ s: String) -> Bool {
        let pattern = #"(?:\(?\+?\d{1,3}\)?[-.\s]?)?(?:\d[-.\s]?){7,}"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    /// Address-like lines combine a street number with a thoroughfare word.
    /// Picking up "1234 MAIN STREET" as the retailer is a common bug.
    private func isAddressLine(_ s: String) -> Bool {
        let pattern = #"\b\d+\s+\w+.*\b(STREET|ST|AVENUE|AVE|ROAD|RD|BOULEVARD|BLVD|WAY|DRIVE|DR|LANE|LN|HIGHWAY|HWY|PARKWAY|PKWY|COURT|CT|PLACE|PL|SUITE|STE|FLOOR)\b\.?"#
        return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// True if the line is a price-only or quantity-only line (no descriptive
    /// content). Used to filter candidates for retailer / product extraction.
    private func isNumericOnlyLine(_ s: String) -> Bool {
        let stripped = s.replacingOccurrences(of: #"[\s$€£¥.,/\-]"#, with: "", options: .regularExpression)
        return !stripped.isEmpty && stripped.allSatisfy(\.isNumber)
    }

    // MARK: - Currency parsing

    /// Match a currency-like number with optional currency symbol and
    /// optional thousand separators. Captures the numeric portion only.
    private static let currencyPattern: String = {
        // Accept $, €, £, ¥, A$, US$ etc. (anything non-digit before the value).
        // Capture group: 1-5 digits, optional thousand groups, then 2 decimals.
        // The decimal may be `.` or `,` (European format).
        return #"(?:^|[^A-Za-z0-9])([0-9]{1,5}(?:,[0-9]{3})*[.,][0-9]{2})(?![0-9])"#
    }()

    private static let currencyRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: currencyPattern)
    }()

    /// Parse a captured numeric string like `"1,234.56"` or `"199,95"` into a
    /// `Double`. Heuristic: if both `.` and `,` present, the rightmost is the
    /// decimal separator. Otherwise treat the single separator as decimal
    /// when followed by exactly 2 digits.
    private func parseCurrencyNumber(_ raw: String) -> Double? {
        var s = raw
        let lastDot = s.lastIndex(of: ".")
        let lastComma = s.lastIndex(of: ",")
        if let dot = lastDot, let comma = lastComma {
            // Both present: the rightmost is the decimal point, the other is
            // the thousand separator and gets stripped.
            if dot > comma {
                s.removeAll { $0 == "," }
            } else {
                s.removeAll { $0 == "." }
                s = s.replacingOccurrences(of: ",", with: ".")
            }
        } else if lastComma != nil, lastDot == nil {
            // Single comma — treat as European decimal.
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        return Double(s)
    }

    /// Returns every currency-like number found in `text`.
    private func pricesIn(_ text: String) -> [Double] {
        guard let regex = Self.currencyRegex else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return parseCurrencyNumber(String(text[captureRange]))
        }
    }

    /// First currency-like number in `text`, or nil.
    private func firstPrice(in text: String) -> Double? {
        pricesIn(text).first
    }

    /// Sanity bounds — receipts above this are probably mis-parsed (decimal
    /// missing). Below this is a tax line or rounding artefact.
    private func validPrice(_ p: Double) -> Bool {
        p >= 0.01 && p < 100_000
    }

    // MARK: - Retailer

    /// Receipts always brand the retailer near the top. We score each
    /// candidate in the top 8 lines and pick the best one. Per-criterion
    /// scoring beats "first match" because real receipts have many caps
    /// lines (tax IDs, store numbers, "RETURNS", "RECEIPT") competing.
    private func parseRetailer(from lines: [Line]) -> String? {
        let blocklist: Set<String> = [
            // Document descriptors
            "RECEIPT", "INVOICE", "ORDER", "TAX INVOICE", "BILL",
            "VAT INVOICE", "SALES RECEIPT", "ORDER SUMMARY", "ITEMIZED RECEIPT",
            "CUSTOMER COPY", "MERCHANT COPY", "DUPLICATE", "REPRINT",
            // Policy / footer text
            "RETURN POLICY", "TERMS", "RETURNS", "REFUND POLICY",
            "ITEMIZED LIST", "PURCHASE", "PAID", "PAYMENT"
        ]
        // Words that almost always appear in taglines / slogans rather than
        // brand names. Their presence is a strong signal we picked wrong.
        let taglineWords: Set<String> = [
            "thank", "welcome", "save", "savings", "quality", "service",
            "rewards", "member", "shopping", "shopper", "open", "hours",
            "store", "manager", "associate", "your", "you"
        ]

        var scored: [(line: String, score: Int)] = []

        for line in lines.prefix(8) {
            let text = line.text
            // Hard rejects.
            guard line.confidence > 0.5 else { continue }
            guard text.count >= 3, text.count <= 50 else { continue }
            guard text.first?.isLetter == true else { continue }
            guard !blocklist.contains(text.uppercased()) else { continue }
            guard !isPhoneLine(text) else { continue }
            guard !isAddressLine(text) else { continue }
            guard !isNumericOnlyLine(text) else { continue }

            var score = 0

            // Position: very top of receipt is strongly preferred.
            score += max(0, 12 - line.index * 2)

            // ALL CAPS bonus — receipts header brands in caps almost always.
            let hasLetters = text.range(of: "[A-Za-z]", options: .regularExpression) != nil
            let isAllCaps = hasLetters && text == text.uppercased()
            if isAllCaps { score += 6 }

            // Title-case bonus (e.g. "Best Buy", "Pottery Barn").
            if !isAllCaps && text.first?.isUppercase == true {
                score += 3
            }

            // Penalise digit content. Branded names rarely have digits.
            let digitCount = text.filter(\.isNumber).count
            score -= digitCount * 2

            // Penalise tagline-like words.
            let lower = text.lowercased()
            let words = lower.split(whereSeparator: { !$0.isLetter }).map(String.init)
            let taglineHits = words.filter { taglineWords.contains($0) }.count
            score -= taglineHits * 4

            // Penalise unusual special characters. "&", "-", "'" are fine
            // ("Crate & Barrel", "Lowe's"); slashes / pipes / asterisks are not.
            let unusual = text.filter { c in
                !c.isLetter && !c.isNumber && !c.isWhitespace
                    && c != "-" && c != "&" && c != "'" && c != "."
            }
            score -= unusual.count * 2

            scored.append((text, score))
        }

        return scored.max(by: { $0.score < $1.score })?.line
    }

    // MARK: - Total price

    /// Try the layout-aware parser first (uses bounding-box geometry to find
    /// the labelled, right-aligned grand total). Fall back to the keyword-only
    /// pipeline when geometry is unavailable (e.g. the `parse(text:)` test
    /// seam) or when no row scored well enough to be confidently picked.
    private func parseTotalPrice(from lines: [Line]) -> Double? {
        if let layoutTotal = parseTotalPriceWithLayout(from: lines) {
            return layoutTotal
        }
        return parseTotalPriceByKeyword(from: lines)
    }

    /// Layout-aware total extraction. Two facts about receipts that the
    /// line-by-line parser can't see:
    ///   - The label and the value are on the *same row* but Vision often
    ///     splits them into separate observations ("TOTAL" left, "$42.50"
    ///     right). Re-clustering by y-coordinate stitches them back together.
    ///   - The grand total is right-aligned and sits near the bottom of the
    ///     receipt. Geometry-based scoring lets us prefer those rows over
    ///     coincidental right-aligned numbers higher up (item prices).
    /// Returns nil when no row scores well enough — the caller falls back to
    /// the keyword-only parser.
    private func parseTotalPriceWithLayout(from lines: [Line]) -> Double? {
        let strongKeywords = [
            "grand total", "total due", "amount due", "balance due",
            "total payment", "you paid", "total to pay", "net total",
            "order total", "total amount"
        ]
        let weakKeywords = ["total", "amount", "balance"]
        let exclusionKeywords = [
            "subtotal", "sub total", "sub-total",
            "cash tendered", "cash tender", "tendered", "cash given",
            "change", "change due", "change given", "change tendered",
            "tax", "vat", "gst", "hst", "pst",
            "qty", "quantity", "items count", "total items", "total qty",
            "discount", "savings", "promo",
            "tip", "gratuity",
            "loyalty", "rewards earned",
            "card", "visa", "mastercard", "amex"
        ]

        // Only consider lines with geometry. The test seam supplies nil.
        let geo = lines.compactMap { line -> (Line, CGRect)? in
            guard let bb = line.boundingBox, line.confidence > 0.4 else { return nil }
            return (line, bb)
        }
        guard geo.count >= 2 else { return nil }

        // Cluster by y-center proximity. Tolerance is half the average line
        // height so it scales with receipt size in the frame.
        let avgHeight = geo.map(\.1.height).reduce(0, +) / CGFloat(geo.count)
        let tolerance = max(avgHeight * 0.5, 0.005)

        // Sort top → bottom (Vision y=1 is the top of the image).
        let sorted = geo.sorted { $0.1.midY > $1.1.midY }

        var rows: [[(Line, CGRect)]] = []
        for entry in sorted {
            if let last = rows.last?.last,
               abs(last.1.midY - entry.1.midY) < tolerance {
                rows[rows.count - 1].append(entry)
            } else {
                rows.append([entry])
            }
        }

        struct Scored { let value: Double; let score: Int; let rowIndex: Int }
        var scored: [Scored] = []

        for (rIdx, row) in rows.enumerated() {
            let leftToRight = row.sorted { $0.1.minX < $1.1.minX }
            let rowText = leftToRight.map(\.0.text).joined(separator: " ")
            let lower = rowText.lowercased()

            // Skip exclusion rows entirely — never let "Cash Tendered" win.
            if exclusionKeywords.contains(where: { lower.contains($0) }) { continue }

            // Right-aligned currency value: pick the rightmost line that
            // contains a valid price.
            var bestPrice: (value: Double, maxX: CGFloat)? = nil
            for (line, bb) in leftToRight {
                let prices = pricesIn(line.text).filter(validPrice)
                guard let v = prices.last else { continue }
                if bestPrice == nil || bb.maxX > bestPrice!.maxX {
                    bestPrice = (v, bb.maxX)
                }
            }
            guard let priceInfo = bestPrice else { continue }
            // Reject left-aligned numbers — those are item prices in the
            // "qty × price" column, not the labelled total.
            guard priceInfo.maxX > 0.55 else { continue }

            var score = 0
            let hasStrong = strongKeywords.contains { lower.contains($0) }
            let hasWeak = weakKeywords.contains { lower.contains($0) }
            if hasStrong { score += 20 }
            else if hasWeak { score += 8 }

            // Position bias: bottom of receipt (Vision y → 0) is where the
            // grand total lives.
            let rowMidY = row.map(\.1.midY).reduce(0, +) / CGFloat(row.count)
            if rowMidY < 0.3 { score += 6 }
            else if rowMidY < 0.5 { score += 3 }

            // Neighbour-row keyword check. Some receipts put "TOTAL" on its
            // own row above the value. Look one row above and one below.
            if !hasStrong && !hasWeak {
                for offset in [-1, 1] {
                    let nIdx = rIdx + offset
                    guard rows.indices.contains(nIdx) else { continue }
                    let neighbourLower = rows[nIdx].map(\.0.text)
                        .joined(separator: " ").lowercased()
                    if exclusionKeywords.contains(where: { neighbourLower.contains($0) }) { continue }
                    if strongKeywords.contains(where: { neighbourLower.contains($0) }) {
                        score += 12
                        break
                    } else if weakKeywords.contains(where: { neighbourLower.contains($0) }) {
                        score += 4
                    }
                }
            }

            // Tiny tiebreaker: among same-keyword rows, prefer the larger
            // value (grand total beats line items). Capped so a misread
            // four-figure value can't outrank a properly-keyworded total.
            score += min(Int(priceInfo.value / 10), 6)

            scored.append(Scored(value: priceInfo.value, score: score, rowIndex: rIdx))
        }

        // Confidence floor — without it we'd return any right-aligned price
        // when nothing was clearly labelled. 10 means at least one solid
        // signal (weak keyword + position, or a strong-keyword neighbour).
        guard let best = scored.max(by: { $0.score < $1.score }),
              best.score >= 10 else { return nil }
        return best.value
    }

    /// Keyword-only fallback. Three-pass extraction:
    ///   1. Strong-keyword pass ("grand total", "amount due", etc.) — a
    ///      labelled total is the highest-quality signal.
    ///   2. Weak-keyword pass ("total", "balance") — *with explicit exclusions*
    ///      so "subtotal" / "cash tendered" / "change" don't slip in.
    ///   3. Fallback: largest number on a non-excluded line.
    /// Each pass validates the parsed value sits in a sane range.
    private func parseTotalPriceByKeyword(from lines: [Line]) -> Double? {
        // Strongest signals — labelled, unambiguous totals.
        let strongKeywords = [
            "grand total", "total due", "amount due", "balance due",
            "total payment", "you paid", "total to pay", "net total",
            "order total", "total amount"
        ]
        // Weaker, ambiguous total keywords. Use only when no strong match
        // and only when no exclusion keyword is also present on the line.
        let weakKeywords = ["total", "amount", "balance"]
        // If any of these substrings appear on a line, the line is NOT a
        // candidate for "the total" — even if a number on it is large.
        let exclusionKeywords = [
            "subtotal", "sub total", "sub-total",
            "cash tendered", "cash tender", "tendered", "cash given",
            "change", "change due", "change given", "change tendered",
            "tax", "vat", "gst", "hst", "pst",
            "qty", "quantity", "items count", "total items", "total qty",
            "discount", "savings", "promo",
            "tip", "gratuity",
            "loyalty", "rewards earned",
            "card", "visa", "mastercard", "amex"
        ]

        // Pass 1: any strong keyword wins.
        for line in lines where line.confidence > 0.5 {
            let lower = line.text.lowercased()
            if strongKeywords.contains(where: { lower.contains($0) }) {
                if let v = firstPrice(in: line.text), validPrice(v) {
                    return v
                }
            }
        }

        // Pass 2: weak keyword + no exclusion.
        for line in lines where line.confidence > 0.5 {
            let lower = line.text.lowercased()
            let hasExclusion = exclusionKeywords.contains(where: { lower.contains($0) })
            guard !hasExclusion else { continue }
            let hasWeak = weakKeywords.contains(where: { lower.contains($0) })
            guard hasWeak else { continue }
            if let v = firstPrice(in: line.text), validPrice(v) {
                return v
            }
        }

        // Pass 3: largest currency value across non-excluded lines.
        // Important: subtotal/tax/etc. lines are filtered out so the fallback
        // doesn't quietly return a misleading "biggest number".
        var allPrices: [Double] = []
        for line in lines where line.confidence > 0.4 {
            let lower = line.text.lowercased()
            if exclusionKeywords.contains(where: { lower.contains($0) }) { continue }
            allPrices.append(contentsOf: pricesIn(line.text).filter(validPrice))
        }
        return allPrices.max()
    }

    // MARK: - Date

    /// Date candidate found in the OCR text — the parsed `Date` plus the
    /// surrounding line text we'll use to score it.
    private struct DateCandidate {
        let date: Date
        let context: String   // the line it was found on, lowercased
    }

    /// Extracts every reasonable date candidate via `NSDataDetector`, then
    /// picks the highest-scored one by keyword proximity ("purchased" → boost,
    /// "due"/"expires" → penalise). Apple's detector covers locale variants,
    /// ordinal suffixes ("the 15th"), abbreviations ("Sept"), and plain
    /// numeric forms — replacing a brittle regex+DateFormatter cascade with
    /// a maintained system parser.
    private func parseDate(from lines: [Line]) -> Date? {
        let purchaseKeywords = [
            "purchased", "purchase date", "sold", "sold on",
            "transaction date", "transaction", "sale date",
            "date of sale", "issue date", "issued"
        ]
        let neutralKeywords = ["date", "order", "receipt", "invoice"]
        let avoidKeywords = ["due", "expires", "expiry", "valid until", "valid through"]

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        var scored: [(date: Date, score: Int)] = []

        for line in lines where line.confidence > 0.4 {
            let text = line.text
            let lower = text.lowercased()
            let purchaseHit = purchaseKeywords.contains { lower.contains($0) }
            let neutralHit = neutralKeywords.contains { lower.contains($0) }
            let avoidHit = avoidKeywords.contains { lower.contains($0) }

            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            for match in detector.matches(in: text, range: range) {
                guard let date = match.date else { continue }
                guard isReasonablePurchaseDate(date) else { continue }
                var score = 0
                if purchaseHit { score += 10 }
                if neutralHit  { score += 4 }
                if avoidHit    { score -= 8 }
                // Slight bias toward dates near the top of the receipt
                // (purchase dates are usually at the top, expiry/due at the bottom).
                score += max(0, 5 - line.index / 4)
                scored.append((date, score))
            }
        }

        // If we have any positively-scored candidate, return the best one.
        // Otherwise fall back to the first reasonable date we saw.
        if let best = scored.max(by: { $0.score < $1.score }), best.score > 0 {
            return best.date
        }
        return scored.first?.date
    }

    /// Reject dates more than 10 years old (warranty receipts that old are
    /// rarely relevant) and any date in the future (almost certainly an
    /// "expires on" date the parser misclassified).
    private func isReasonablePurchaseDate(_ date: Date) -> Bool {
        let now = Date()
        guard let tenYearsAgo = Calendar.current.date(byAdding: .year, value: -10, to: now) else { return false }
        return date <= now && date >= tenYearsAgo
    }

    // MARK: - Product name

    /// Pick the most plausible product description: a meaty, mostly-letters
    /// line that isn't a header / footer / total / boilerplate. Prefer lines
    /// in the "items" section (middle of the receipt, after the header but
    /// before the totals block).
    private func parseProductName(from lines: [Line]) -> String? {
        // Boilerplate patterns we'd never want as a product name.
        let boilerplateContains: [String] = [
            "thank", "thanks", "welcome", "shopping",
            "return policy", "returns", "refund",
            "see store", "see receipt", "more details",
            "rewards", "loyalty", "member",
            "follow us", "visit us", "facebook", "twitter", "instagram",
            "feedback", "survey", "rate us",
            "register", "cashier", "checker",
            "transaction", "merchant copy", "customer copy",
            "have a", "good day", "great day",
        ]
        // Tokens that mark a totals/payments line.
        let totalsTokens = ["total", "subtotal", "tax", "amount", "balance", "due",
                            "change", "tender", "card", "cash", "visa", "mastercard"]

        var scored: [(text: String, score: Int)] = []

        // Skip the first 2 lines (header) — those are the retailer / address /
        // store number / phone, almost never the product itself.
        for line in lines.dropFirst(2) where line.confidence > 0.5 {
            let text = line.text
            let lower = text.lowercased()

            // Hard rejects.
            guard text.count >= 4, text.count <= 80 else { continue }
            guard text.range(of: "[A-Za-z]", options: .regularExpression) != nil else { continue }
            guard !isPhoneLine(text), !isAddressLine(text) else { continue }
            guard !isNumericOnlyLine(text) else { continue }
            // Skip lines that are mostly digits/symbols.
            let letterCount = text.filter(\.isLetter).count
            guard letterCount * 2 >= text.count else { continue }

            // ALL CAPS lines on receipts are usually labels ("CASH", "VISA",
            // "STORE #1234"). Skip them when scoring product candidates.
            let isAllCaps = text == text.uppercased()
                && text.range(of: "[A-Z]", options: .regularExpression) != nil
            if isAllCaps { continue }

            if boilerplateContains.contains(where: { lower.contains($0) }) { continue }
            if totalsTokens.contains(where: { lower.contains($0) }) { continue }

            // Score: longer is better, but cap so a 60-char terms-clause
            // doesn't out-rank a 25-char product name.
            var score = min(text.count, 35)
            // Has both letters and a number — common in product lines like
            // "iPhone 15 Pro 256GB" or "Samsung 65\" QLED".
            let hasLetters = letterCount > 0
            let hasDigits = text.filter(\.isNumber).count > 0
            if hasLetters && hasDigits { score += 8 }
            // Contains common product nouns — a soft signal.
            let productNouns = ["pro", "max", "plus", "ultra", "edition",
                                "model", "series", "inch", "gb", "tb",
                                "watch", "phone", "tv", "laptop"]
            if productNouns.contains(where: { lower.contains($0) }) {
                score += 4
            }
            // Prefer lines closer to the top of the items block (after the
            // header) — first product is usually the one the user thinks of.
            score += max(0, 6 - line.index / 3)

            scored.append((text, score))
        }

        return scored.max(by: { $0.score < $1.score })?.text
    }
}
