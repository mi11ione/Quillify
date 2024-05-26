import SwiftUI

struct WelcomeView: View {
    @ObservedObject var windowState: WindowState
    @StateObject var viewModel = WelcomeViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                switch viewModel.welcomeState {
                case .welcomeMessage:
                    WelcomeMessageView()
                        .transition(viewModel.transition)
                case .learnTools:
                    ToolsView()
                        .transition(viewModel.transition)
                case .selectPhoto:
                    PhotoPickerView(windowState: windowState)
                        .transition(viewModel.transition)
                }
            }

            if viewModel.welcomeState != .selectPhoto {
                VStack {
                    Spacer()
                    Button(action: { viewModel.buttonAction() }) {
                        Text(viewModel.buttonMessage())
                            .font(.headline)
                            .bold()
                            .foregroundColor(Color(uiColor: UIColor.systemBackground))
                            .padding()
                            .frame(width: 200)
                            .background(Color.accentColor)
                            .cornerRadius(15)
                    }
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                }
            }
        }
    }
}
