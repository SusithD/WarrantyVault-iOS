import SwiftUI

struct OnboardingContainerView: View {
    var onComplete: () -> Void

    @State private var currentIndex = 0

    private var pages: [OnboardingPage] { OnboardingContent.pages }

    var body: some View {
        ZStack {
            GradientBackground()

            TabView(selection: $currentIndex) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        page: pages[index],
                        currentIndex: index,
                        totalPages: pages.count,
                        onNext: { advance() },
                        onSkip: { onComplete() }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
        }
    }

    private func advance() {
        if currentIndex < pages.count - 1 {
            withAnimation { currentIndex += 1 }
        } else {
            onComplete()
        }
    }
}

#Preview {
    OnboardingContainerView(onComplete: {})
}
