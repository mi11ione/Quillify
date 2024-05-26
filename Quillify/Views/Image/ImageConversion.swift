import Combine
import PencilKit
import SwiftUI

class ImageConversion: ObservableObject {
    let image: UIImage
    @Published var paths: [([CGPoint], UIColor)]? = nil

    lazy var scaleTransform: CGAffineTransform = {
        let dimension: CGFloat = 400
        guard let cgImage = image.cgImage else { return .identity }
        let maxDimension = CGFloat(max(cgImage.width, cgImage.height))
        let scale = dimension / maxDimension
        return CGAffineTransform(scaleX: scale, y: scale)
    }()

    var translateTransform: CGAffineTransform = .identity

    var transform: CGAffineTransform {
        scaleTransform.concatenating(translateTransform)
    }

    var isConversionFinished: Bool {
        paths != nil
    }

    init(image: UIImage, position: CGPoint) {
        self.image = image
        setupTransforms(position: position)
    }

    private func setupTransforms(position: CGPoint) {
        let size = image.size
        let rect = CGRect(origin: .zero, size: size).applying(scaleTransform)
        translateTransform = CGAffineTransform(translationX: position.x - rect.width / 2, y: position.y - rect.height / 2)
    }

    func applyTranslate(transform: CGAffineTransform) {
        translateTransform = translateTransform.concatenating(transform)
    }

    func applyScale(transform: CGAffineTransform) {
        scaleTransform = scaleTransform.concatenating(transform)
    }

    func convert() {
        Task {
            let convertedPaths = ImagePathConverter(image: image).findPaths()
            DispatchQueue.main.async {
                self.paths = convertedPaths.map { $0 }
            }
        }
    }

    func getStrokes() -> [PKStroke] {
        guard let paths else { return [] }
        return paths.map { points, color in
            let transformedPoints = points.map { point in
                PKStrokePoint(location: point.applying(transform), timeOffset: 0, size: CGSize(width: 3, height: 3), opacity: 1, force: 2, azimuth: 0, altitude: 0)
            }
            let path = PKStrokePath(controlPoints: transformedPoints, creationDate: Date())
            return PKStroke(ink: PKInk(.pen, color: color), path: path, transform: .identity, mask: nil)
        }
    }
}
