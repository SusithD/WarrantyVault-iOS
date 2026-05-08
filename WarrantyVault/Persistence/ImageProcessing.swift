import UIKit
import CoreGraphics

extension UIImage {
    /// Downscale so the longest edge is at most `maxDimension` (in points) and
    /// JPEG-encode at the given `quality` (0...1). Returns `nil` if encoding
    /// fails. Used to keep persisted receipt images small before saving to
    /// Core Data with external binary data storage.
    func receiptEncoded(maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1.0
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0   // 1pt == 1px on disk
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Returns a `CGImage` whose long edge is at most `maxDimension`. If the
    /// receiver is already smaller, returns the underlying CGImage as-is.
    /// Used to bound work done by Vision OCR for speed.
    func downscaledCGImage(maxDimension: CGFloat) -> CGImage? {
        let longest = max(size.width, size.height)
        if longest <= maxDimension { return cgImage }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.cgImage
    }
}
