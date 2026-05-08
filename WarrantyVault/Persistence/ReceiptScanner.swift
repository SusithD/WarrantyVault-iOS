import Foundation
import UIKit
@preconcurrency import Vision


struct ReceiptScanResult {
    var rawText: String
    var productName: String?
    var retailer: String?
    var purchaseDate: Date?
    var totalPrice: Double?

    static let empty = ReceiptScanResult(rawText: "")
}


final class ReceiptScanner {

    static let shared = ReceiptScanner()

    enum Failure: Error {
        case noCGImage
        case underlying(Error)
    }


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


    private func cleanText(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)

        let collapsed = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let filtered = collapsed.unicodeScalars.filter {
            !($0.value < 0x20 || $0.value == 0x7F)
        }
        return String(String.UnicodeScalarView(filtered))
    }


    private func isPhoneLine(_ s: String) -> Bool {
        let pattern = #"(?:\(?\+?\d{1,3}\)?[-.\s]?)?(?:\d[-.\s]?){7,}"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }


    private func isAddressLine(_ s: String) -> Bool {
        let pattern = #"\b\d+\s+\w+.*\b(STREET|ST|AVENUE|AVE|ROAD|RD|BOULEVARD|BLVD|WAY|DRIVE|DR|LANE|LN|HIGHWAY|HWY|PARKWAY|PKWY|COURT|CT|PLACE|PL|SUITE|STE|FLOOR)\b\.?"#
        return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }


    private func isNumericOnlyLine(_ s: String) -> Bool {
        let stripped = s.replacingOccurrences(of: #"[\s$€£¥.,/\-]"#, with: "", options: .regularExpression)
        return !stripped.isEmpty && stripped.allSatisfy(\.isNumber)
    }


    private static let currencyPattern: String = {


        return #"(?:^|[^A-Za-z0-9])([0-9]{1,5}(?:,[0-9]{3})*[.,][0-9]{2})(?![0-9])"#
    }()

    private static let currencyRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: currencyPattern)
    }()


    private func parseCurrencyNumber(_ raw: String) -> Double? {
        var s = raw
        let lastDot = s.lastIndex(of: ".")
        let lastComma = s.lastIndex(of: ",")
        if let dot = lastDot, let comma = lastComma {


            if dot > comma {
                s.removeAll { $0 == "," }
            } else {
                s.removeAll { $0 == "." }
                s = s.replacingOccurrences(of: ",", with: ".")
            }
        } else if lastComma != nil, lastDot == nil {

            s = s.replacingOccurrences(of: ",", with: ".")
        }
        return Double(s)
    }


    private func pricesIn(_ text: String) -> [Double] {
        guard let regex = Self.currencyRegex else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return parseCurrencyNumber(String(text[captureRange]))
        }
    }


    private func firstPrice(in text: String) -> Double? {
        pricesIn(text).first
    }


    private func validPrice(_ p: Double) -> Bool {
        p >= 0.01 && p < 100_000
    }


    private func parseRetailer(from lines: [Line]) -> String? {
        let blocklist: Set<String> = [

            "RECEIPT", "INVOICE", "ORDER", "TAX INVOICE", "BILL",
            "VAT INVOICE", "SALES RECEIPT", "ORDER SUMMARY", "ITEMIZED RECEIPT",
            "CUSTOMER COPY", "MERCHANT COPY", "DUPLICATE", "REPRINT",

            "RETURN POLICY", "TERMS", "RETURNS", "REFUND POLICY",
            "ITEMIZED LIST", "PURCHASE", "PAID", "PAYMENT"
        ]


        let taglineWords: Set<String> = [
            "thank", "welcome", "save", "savings", "quality", "service",
            "rewards", "member", "shopping", "shopper", "open", "hours",
            "store", "manager", "associate", "your", "you"
        ]

        var scored: [(line: String, score: Int)] = []

        for line in lines.prefix(8) {
            let text = line.text

            guard line.confidence > 0.5 else { continue }
            guard text.count >= 3, text.count <= 50 else { continue }
            guard text.first?.isLetter == true else { continue }
            guard !blocklist.contains(text.uppercased()) else { continue }
            guard !isPhoneLine(text) else { continue }
            guard !isAddressLine(text) else { continue }
            guard !isNumericOnlyLine(text) else { continue }

            var score = 0


            score += max(0, 12 - line.index * 2)


            let hasLetters = text.range(of: "[A-Za-z]", options: .regularExpression) != nil
            let isAllCaps = hasLetters && text == text.uppercased()
            if isAllCaps { score += 6 }


            if !isAllCaps && text.first?.isUppercase == true {
                score += 3
            }


            let digitCount = text.filter(\.isNumber).count
            score -= digitCount * 2


            let lower = text.lowercased()
            let words = lower.split(whereSeparator: { !$0.isLetter }).map(String.init)
            let taglineHits = words.filter { taglineWords.contains($0) }.count
            score -= taglineHits * 4


            let unusual = text.filter { c in
                !c.isLetter && !c.isNumber && !c.isWhitespace
                    && c != "-" && c != "&" && c != "'" && c != "."
            }
            score -= unusual.count * 2

            scored.append((text, score))
        }

        return scored.max(by: { $0.score < $1.score })?.line
    }


    private func parseTotalPrice(from lines: [Line]) -> Double? {
        if let layoutTotal = parseTotalPriceWithLayout(from: lines) {
            return layoutTotal
        }
        return parseTotalPriceByKeyword(from: lines)
    }


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


        let geo = lines.compactMap { line -> (Line, CGRect)? in
            guard let bb = line.boundingBox, line.confidence > 0.4 else { return nil }
            return (line, bb)
        }
        guard geo.count >= 2 else { return nil }


        let avgHeight = geo.map(\.1.height).reduce(0, +) / CGFloat(geo.count)
        let tolerance = max(avgHeight * 0.5, 0.005)


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


            if exclusionKeywords.contains(where: { lower.contains($0) }) { continue }


            var bestPrice: (value: Double, maxX: CGFloat)? = nil
            for (line, bb) in leftToRight {
                let prices = pricesIn(line.text).filter(validPrice)
                guard let v = prices.last else { continue }
                if bestPrice == nil || bb.maxX > bestPrice!.maxX {
                    bestPrice = (v, bb.maxX)
                }
            }
            guard let priceInfo = bestPrice else { continue }


            guard priceInfo.maxX > 0.55 else { continue }

            var score = 0
            let hasStrong = strongKeywords.contains { lower.contains($0) }
            let hasWeak = weakKeywords.contains { lower.contains($0) }
            if hasStrong { score += 20 }
            else if hasWeak { score += 8 }


            let rowMidY = row.map(\.1.midY).reduce(0, +) / CGFloat(row.count)
            if rowMidY < 0.3 { score += 6 }
            else if rowMidY < 0.5 { score += 3 }


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


            score += min(Int(priceInfo.value / 10), 6)

            scored.append(Scored(value: priceInfo.value, score: score, rowIndex: rIdx))
        }


        guard let best = scored.max(by: { $0.score < $1.score }),
              best.score >= 10 else { return nil }
        return best.value
    }


    private func parseTotalPriceByKeyword(from lines: [Line]) -> Double? {

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


        for line in lines where line.confidence > 0.5 {
            let lower = line.text.lowercased()
            if strongKeywords.contains(where: { lower.contains($0) }) {
                if let v = firstPrice(in: line.text), validPrice(v) {
                    return v
                }
            }
        }


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


        var allPrices: [Double] = []
        for line in lines where line.confidence > 0.4 {
            let lower = line.text.lowercased()
            if exclusionKeywords.contains(where: { lower.contains($0) }) { continue }
            allPrices.append(contentsOf: pricesIn(line.text).filter(validPrice))
        }
        return allPrices.max()
    }


    private struct DateCandidate {
        let date: Date
        let context: String
    }


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


                score += max(0, 5 - line.index / 4)
                scored.append((date, score))
            }
        }


        if let best = scored.max(by: { $0.score < $1.score }), best.score > 0 {
            return best.date
        }
        return scored.first?.date
    }


    private func isReasonablePurchaseDate(_ date: Date) -> Bool {
        let now = Date()
        guard let tenYearsAgo = Calendar.current.date(byAdding: .year, value: -10, to: now) else { return false }
        return date <= now && date >= tenYearsAgo
    }


    private func parseProductName(from lines: [Line]) -> String? {

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

        let totalsTokens = ["total", "subtotal", "tax", "amount", "balance", "due",
                            "change", "tender", "card", "cash", "visa", "mastercard"]

        var scored: [(text: String, score: Int)] = []


        for line in lines.dropFirst(2) where line.confidence > 0.5 {
            let text = line.text
            let lower = text.lowercased()


            guard text.count >= 4, text.count <= 80 else { continue }
            guard text.range(of: "[A-Za-z]", options: .regularExpression) != nil else { continue }
            guard !isPhoneLine(text), !isAddressLine(text) else { continue }
            guard !isNumericOnlyLine(text) else { continue }

            let letterCount = text.filter(\.isLetter).count
            guard letterCount * 2 >= text.count else { continue }


            let isAllCaps = text == text.uppercased()
                && text.range(of: "[A-Z]", options: .regularExpression) != nil
            if isAllCaps { continue }

            if boilerplateContains.contains(where: { lower.contains($0) }) { continue }
            if totalsTokens.contains(where: { lower.contains($0) }) { continue }


            var score = min(text.count, 35)


            let hasLetters = letterCount > 0
            let hasDigits = text.filter(\.isNumber).count > 0
            if hasLetters && hasDigits { score += 8 }

            let productNouns = ["pro", "max", "plus", "ultra", "edition",
                                "model", "series", "inch", "gb", "tb",
                                "watch", "phone", "tv", "laptop"]
            if productNouns.contains(where: { lower.contains($0) }) {
                score += 4
            }


            score += max(0, 6 - line.index / 3)

            scored.append((text, score))
        }

        return scored.max(by: { $0.score < $1.score })?.text
    }
}
