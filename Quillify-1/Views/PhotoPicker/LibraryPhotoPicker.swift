//
//  LibraryPhotoPicker.swift
//  Quillify
//
//  Created by mi11ion on 19/3/24.
//

import Combine
import PhotosUI
import SwiftUI

class LibraryPhotoPicker: UIViewController, PHPickerViewControllerDelegate {
    let state: WindowState
    var cancellable: AnyCancellable? = nil
    var imagePicker: PHPickerViewController? = nil

    init(state: WindowState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        let filter = PHPickerFilter.any(of: [.images])
        configuration.filter = filter
        configuration.preferredAssetRepresentationMode = .compatible
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        imagePicker = picker
        picker.delegate = self

        cancellable = state.$photoMode.sink(receiveValue: { [weak self] mode in
            guard let self = self, let picker = self.imagePicker else { return }
            if mode == .library {
                self.present(picker, animated: true)
            } else {
                picker.dismiss(animated: true)
            }
        })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func picker(_: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // dismiss picker
        state.photoMode = .none
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] photo, _ in
            guard let self = self, let image = photo as? UIImage else { return }
            Task { @MainActor in
                await self.state.startConversion(image: image)
            }
        }
    }
}

struct LibraryPhotoPickerView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState

    func makeUIViewController(context _: Context) -> UIViewController {
        LibraryPhotoPicker(state: windowState)
    }

    func updateUIViewController(_: UIViewController, context _: Context) {
        // ignore
    }
}
