import SwiftUI
import VisionKit
import UIKit

/// SwiftUI wrapper around `VNDocumentCameraViewController` — the same scanner
/// used by Notes / Files. Receipts come back pre-cropped and perspective-
/// corrected, which materially improves OCR over a raw camera frame.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScanned: (UIImage) -> Void
    var onCancel: () -> Void = {}

    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanned: (UIImage) -> Void
        let onCancel: () -> Void

        init(onScanned: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onScanned = onScanned
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            if scan.pageCount > 0 {
                onScanned(scan.imageOfPage(at: 0))
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCancel()
            controller.dismiss(animated: true)
        }
    }
}
