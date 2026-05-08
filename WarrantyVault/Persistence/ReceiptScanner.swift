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
/// Always runs on the device — no network calls — and is bounded to a 2000pt
/// long edge for responsiveness.
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
            purchaseDate: parseDate(from: rawText),
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
            .map { Line(text: String($0), confidence: 0.95) }

        return ReceiptScanResult(
            rawText: text,
            productName: parseProductName(from: lines),
            retailer:    parseRetailer(from: lines),
            purchaseDate: parseDate(from: text),
            totalPrice:  parseTotalPrice(from: lines)
        )
    }

    // MARK: - Vision

    private struct Line {
        let text: String
        let confidence: Float
    }

    private func recognizeText(in cgImage: CGImage) async throws -> [Line] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    cont.resume(throwing: Failure.underlying(error))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [Line] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return Line(text: candidate.string, confidence: candidate.confidence)
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

    // MARK: - Parsers

    /// Retailer is usually one of the very first lines on the receipt and
    /// is often all caps. Skip obvious boilerplate. Confidence floor 0.5.
    private func parseRetailer(from lines: [Line]) -> String? {
        let blocklist: Set<String> = [
            "RECEIPT", "INVOICE", "ORDER", "TAX INVOICE", "BILL", "VAT INVOICE", "SALES RECEIPT"
        ]

        let candidates = lines.prefix(5)
            .filter { $0.confidence > 0.5 }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard line.count >= 3 else { return false }
                guard line.rangeOfCharacter(from: .letters) != nil else { return false }
                guard line.first?.isLetter == true else { return false }
                return !blocklist.contains(line.uppercased())
            }

        // Prefer the first all-caps line if present.
        if let allCaps = candidates.first(where: { $0 == $0.uppercased() && $0.count >= 3 }) {
            return allCaps
        }
        return candidates.first
    }

    /// Product name is the longest line (≥ 4 chars) that's not the retailer
    /// and not a price/date/keyword line.
    private func parseProductName(from lines: [Line]) -> String? {
        let priceKeywords = ["total", "subtotal", "tax", "amount", "balance", "due", "change", "card"]
        let priceLikeRegex = (try? NSRegularExpression(pattern: #"^\$?\s*\d+[.,]\d{2}\s*$"#)) ?? nil
        let dateLikeRegex  = (try? NSRegularExpression(pattern: #"\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}"#)) ?? nil

        let candidates = lines.dropFirst(2)
            .filter { $0.confidence > 0.5 }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let lower = line.lowercased()
                guard line.count >= 4 else { return false }
                guard line.rangeOfCharacter(from: .letters) != nil else { return false }
                guard !priceKeywords.contains(where: { lower.contains($0) }) else { return false }

                let nsLine = line as NSString
                let range = NSRange(location: 0, length: nsLine.length)
                if priceLikeRegex?.firstMatch(in: line, range: range) != nil { return false }
                if dateLikeRegex?.firstMatch(in: line, range: range) != nil { return false }
                return true
            }

        return candidates.max { $0.count < $1.count }
    }

    /// Total price: prefer a line containing TOTAL/AMOUNT/BALANCE that also
    /// has a currency-like number. Fall back to the largest price found
    /// anywhere if no labelled total is present.
    private func parseTotalPrice(from lines: [Line]) -> Double? {
        let priceRegex = try? NSRegularExpression(pattern: #"\$?\s*([0-9]+[\.,][0-9]{2})"#)

        // Pass 1: labelled total (but not subtotal).
        for line in lines where line.confidence > 0.5 {
            let lower = line.text.lowercased()
            let isTotalLine = (lower.contains("total") && !lower.contains("subtotal"))
                || lower.contains("amount due")
                || lower.contains("balance due")
            guard isTotalLine else { continue }

            if let value = firstPrice(in: line.text, with: priceRegex) {
                return value
            }
        }

        // Pass 2: largest currency-like number anywhere on the receipt.
        var collected: [Double] = []
        for line in lines where line.confidence > 0.4 {
            collected.append(contentsOf: pricesIn(line.text, with: priceRegex))
        }
        return collected.max()
    }

    private func firstPrice(in text: String, with regex: NSRegularExpression?) -> Double? {
        guard let regex else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[captureRange].replacingOccurrences(of: ",", with: "."))
    }

    private func pricesIn(_ text: String, with regex: NSRegularExpression?) -> [Double] {
        guard let regex else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[captureRange].replacingOccurrences(of: ",", with: "."))
        }
    }

    /// Date: try common numeric patterns (US first, then ISO, then EU).
    /// Reject parsed dates more than 5 years old or in the future.
    private func parseDate(from text: String) -> Date? {
        let formatters: [DateFormatter] = [
            "MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy",
            "MM-dd-yyyy", "M-d-yyyy",
            "MM.dd.yyyy", "M.d.yyyy",
            "yyyy-MM-dd",
            "dd/MM/yyyy", "d/M/yyyy",
            "dd-MM-yyyy", "d-M-yyyy",
        ].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }

        let pattern = #"\b(\d{1,4}[/.\-]\d{1,2}[/.\-]\d{1,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let raw = nsText.substring(with: match.range)
            for formatter in formatters {
                if let date = formatter.date(from: raw), isReasonablePurchaseDate(date) {
                    return date
                }
            }
        }
        return nil
    }

    private func isReasonablePurchaseDate(_ date: Date) -> Bool {
        let now = Date()
        guard let fiveYearsAgo = Calendar.current.date(byAdding: .year, value: -5, to: now) else { return false }
        return date <= now && date >= fiveYearsAgo
    }
}
