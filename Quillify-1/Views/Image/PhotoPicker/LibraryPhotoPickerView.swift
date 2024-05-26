import SwiftUI
import PhotosUI

struct LibraryPhotoPickerView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if windowState.photoMode == .library {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = PHPickerFilter.images
            configuration.selectionLimit = 1

            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            uiViewController.present(picker, animated: true) {
                windowState.photoMode = .none
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(windowState: windowState)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var windowState: WindowState

        init(windowState: WindowState) {
            self.windowState = windowState
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] photo, _ in
                guard let self = self, let image = photo as? UIImage else { return }
                Task {
                    await self.windowState.startConversion(image: image)
                }
            }
        }
    }
}
