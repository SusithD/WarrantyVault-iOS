import Foundation
import FirebaseCore


enum FirebaseSetup {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
