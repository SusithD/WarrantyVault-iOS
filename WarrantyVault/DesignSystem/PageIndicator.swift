import SwiftUI

struct PageIndicator: View {
    let total: Int
    let current: Int
    var activeColor: Color = AppColors.accent
    var inactiveColor: Color = AppColors.bgSurfaceHi

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? activeColor : inactiveColor)
                    .frame(
                        width: index == current ? 24 : 8,
                        height: 3
                    )
                    .animation(.easeInOut(duration: 0.22), value: current)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        PageIndicator(total: 3, current: 0)
        PageIndicator(total: 3, current: 1)
        PageIndicator(total: 3, current: 2)
    }
    .padding()
    .background(GradientBackground())
}
