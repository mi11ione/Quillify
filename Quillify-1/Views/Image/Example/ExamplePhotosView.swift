import SwiftUI

struct ExamplePhotosView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ExamplePhotosController
    var windowState: WindowState

    func makeUIViewController(context: Context) -> ExamplePhotosController {
        ExamplePhotosController(windowState: windowState)
    }

    func updateUIViewController(_ uiViewController: ExamplePhotosController, context: Context) {
        // No updates needed
    }
}
