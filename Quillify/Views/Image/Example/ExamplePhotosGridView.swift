import SwiftUI

struct ExamplePhotosGridView: View {
    @ObservedObject var windowState: WindowState
    let photoColumns = [GridItem](repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
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
    }

    func cancel() {
        windowState.photoMode = .none
    }

    func convert(image: UIImage) {
        windowState.photoMode = .none
        Task {
            await windowState.startConversion(image: image)
        }
    }
}
