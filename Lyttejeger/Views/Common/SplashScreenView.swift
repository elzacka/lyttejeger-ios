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
        .task {
            if UIAccessibility.isReduceMotionEnabled {
                try? await Task.sleep(for: .milliseconds(500))
                onFinished()
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    scale = 1.0
                    rotation = 360
                }

                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 0
                }

                try? await Task.sleep(for: .milliseconds(300))
                onFinished()
            }
        }
    }
}
