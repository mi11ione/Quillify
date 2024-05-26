import SwiftUI

struct CanvasView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState

    func makeUIViewController(context _: Context) -> UIViewController {
        Canvas(state: windowState)
    }

    func updateUIViewController(_: UIViewController, context _: Context) {
        // ignore
    }
}
