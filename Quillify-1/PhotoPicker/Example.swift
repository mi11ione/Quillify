//
//  Example.swift
//  Quillify
//
//  Created by mi11ion on 17/4/24.
//

import Combine
import SwiftUI

class ExamplePhotos {
    static var photos: [UIImage] = [UIImage(named: "example1.heic"),
                                    UIImage(named: "example2.jpg"),
                                    UIImage(named: "example3.jpg"),
                                    UIImage(named: "example4.jpg")].compactMap { $0 }
}

struct ExamplePhotosNavigationView: View {
    @ObservedObject var windowState: WindowState
    let photoColumns = [GridItem](repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
        NavigationView {
            VStack {
                LazyVGrid(columns: photoColumns, spacing: 1) {
                    ForEach(ExamplePhotos.photos, id: \.self) { image in
                        Button(action: { convert(image: image) }) {
                            Rectangle()
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                )
                                .clipShape(Rectangle())
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Демо")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отменить", action: { cancel() })
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    func cancel() {
        windowState.photoMode = .none
    }

    func convert(image: UIImage) {
        windowState.photoMode = .none
        Task { @MainActor in
            await windowState.startConversion(image: image)
        }
    }
}

class ExamplePhotosController: UIViewController {
    var state: WindowState
    var picker: UIHostingController<ExamplePhotosNavigationView>?
    var cancellable: AnyCancellable? = nil

    init(windowState: WindowState) {
        state = windowState
        super.init(nibName: nil, bundle: nil)
        cancellable = state.$photoMode.sink(receiveValue: { [weak self] mode in
            guard let self = self else { return }
            if mode == .example {
                let picker = UIHostingController(rootView: ExamplePhotosNavigationView(windowState: windowState))
                self.picker = picker
                self.present(picker, animated: true)
            } else {
                self.picker?.dismiss(animated: true)
            }
        })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ExamplePhotosView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ExamplePhotosController
    var windowState: WindowState

    func makeUIViewController(context _: Context) -> ExamplePhotosController {
        ExamplePhotosController(windowState: windowState)
    }

    func updateUIViewController(_: ExamplePhotosController, context _: Context) {
        // ignore
    }
}
