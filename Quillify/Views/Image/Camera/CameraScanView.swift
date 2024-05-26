import SwiftUI

struct CameraScanView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState

    func makeUIViewController(context: Context) -> CameraScan {
        CameraScan(windowState: windowState, viewModel: context.coordinator)
    }

    func updateUIViewController(_: CameraScan, context _: Context) {
        // ignore
    }

    func makeCoordinator() -> CameraScanViewModel {
        CameraScanViewModel(windowState: windowState)
    }
}
