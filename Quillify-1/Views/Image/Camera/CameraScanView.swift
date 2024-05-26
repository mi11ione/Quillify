import SwiftUI

struct CameraScanView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState

    func makeUIViewController(context: Context) -> CameraScan {
        return CameraScan(windowState: windowState, viewModel: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: CameraScan, context: Context) {
        // Ignore
    }

    func makeCoordinator() -> CameraScanViewModel {
        return CameraScanViewModel(windowState: windowState)
    }
}
