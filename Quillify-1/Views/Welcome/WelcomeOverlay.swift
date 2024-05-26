import SwiftUI

struct WelcomeOverlay: View {
    @ObservedObject var windowState: WindowState

    var body: some View {
        Rectangle()
            .foregroundColor(Color(uiColor: UIColor.systemBackground))
            .ignoresSafeArea()
            .opacity(0.95)

        WelcomeView(windowState: windowState)
    }
}
