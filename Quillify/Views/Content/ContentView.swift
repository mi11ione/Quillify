import SwiftUI

struct ContentView: View {
    @StateObject private var windowState = WindowState()

    private var isShowingWelcome: Bool {
        windowState.photoMode == .welcome
    }

    var body: some View {
        ZStack {
            CanvasDrawView(windowState: windowState)
                .disabled(isShowingWelcome)
                .accessibilityHidden(isShowingWelcome)
                .opacity(isShowingWelcome ? 0 : 1)

            if isShowingWelcome {
                WelcomeOverlay(windowState: windowState)
            }
        }
    }
}
