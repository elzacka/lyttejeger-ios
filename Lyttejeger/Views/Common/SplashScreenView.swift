import SwiftUI

struct SplashScreenView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 1

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                .scaleEffect(scale)
        }
        .opacity(opacity)
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled {
                // Skip animation, just show briefly then dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onFinished()
                }
            } else {
                // Phase 1: Scale up + gentle Y-axis spin (0.8s)
                withAnimation(.easeOut(duration: 0.8)) {
                    scale = 1.0
                    rotation = 360
                }

                // Phase 2: Fade out (0.4s after spin completes)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 0
                    }
                }

                // Phase 3: Remove splash
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    onFinished()
                }
            }
        }
    }
}
