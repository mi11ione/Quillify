import SwiftUI

struct ExamplePhotosView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ExamplePhotosController
    var windowState: WindowState

    func makeUIViewController(context _: Context) -> ExamplePhotosController {
        ExamplePhotosController(windowState: windowState)
    }

    func updateUIViewController(_: ExamplePhotosController, context _: Context) {
        // No updates needed
    }
}
