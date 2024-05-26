import SwiftUI

class WelcomeViewModel: ObservableObject {
    @Published var welcomeState: WelcomeState = .welcomeMessage

    var transition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity))
    }

    func buttonAction() {
        switch welcomeState {
        case .welcomeMessage:
            withAnimation { welcomeState = .learnTools }
        case .learnTools:
            withAnimation { welcomeState = .selectPhoto }
        case .selectPhoto:
            break
        }
    }

    func buttonMessage() -> String {
        switch welcomeState {
        case .welcomeMessage:
            "Интересно"
        case .learnTools:
            "Го рисовать"
        case .selectPhoto:
            ""
        }
    }
}
