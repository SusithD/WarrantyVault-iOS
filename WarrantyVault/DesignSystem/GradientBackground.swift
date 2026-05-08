import SwiftUI

struct GradientBackground: View {
    var body: some View {
        AppColors.bgApp
            .ignoresSafeArea()
    }
}

typealias SolidBackground = GradientBackground

#Preview {
    GradientBackground()
}
