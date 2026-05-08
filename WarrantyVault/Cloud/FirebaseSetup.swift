import Foundation
import FirebaseCore

/// Boots Firebase exactly once. Called from `WarrantyVaultApp.init()`
/// before any code that touches `Auth`, `Firestore`, etc.
enum FirebaseSetup {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
