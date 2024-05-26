import Combine
import PencilKit
import SwiftUI

class WindowState: ObservableObject {
    @Published var currentColor: SemanticColor = .primary
    @Published var currentTool: CanvasTool = .pen {
        willSet {
            handleToolChange(newTool: newValue)
        }
    }
    @Published var selection: Set<Int>? = nil {
        willSet {
            handleSelectionChange()
        }
    }
    @Published var isShowingPenColorPicker: Bool = false
    @Published var isShowingSelectionColorPicker: Bool = false
    @Published var photoMode: PhotoMode = .welcome
    @Published var finalizeImage: UIImage? = nil

    var imageConversion: ImageConversion? = nil
    var imageCancellable: AnyCancellable? = nil
    weak var canvas: Canvas? = nil

    var hasSelection: Bool {
        selection != nil
    }

    var isShowingPopover: Bool {
        isShowingPenColorPicker || isShowingSelectionColorPicker
    }

    var selectedStrokes: [(Int, PKStroke)] {
        guard let selection = selection else { return [] }
        return canvas?.strokes.enumerated().filter { index, _ in selection.contains(index) } ?? []
    }

    var selectionColors: Set<UIColor> {
        var colors = Set<UIColor>()
        return selectedStrokes.reduce(into: colors) { colorSet, path in
            let dynamicColor = SemanticColor.adaptiveInvertedBrightness(color: path.1.ink.color)
            if !colors.contains(path.1.ink.color) {
                colors.insert(path.1.ink.color)
                colorSet.insert(dynamicColor)
            }
        }
    }

    var pencilSelectionColors: Set<UIColor> {
        Set(selectionColors.map { $0.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)) })
    }

    func addStrokes(strokes: [PKStroke]) {
        canvas?.addStrokes(strokes)
    }

    func recolorSelection(newColor: SemanticColor) throws {
        guard hasSelection else { throw SelectionModifyError.noSelection }
        let recoloredStrokes = selectedStrokes.map { index, stroke in
            (index, PKStroke(ink: PKInk(.pen, color: newColor.pencilKitColor), path: stroke.path, transform: stroke.transform, mask: stroke.mask))
        }
        canvas?.updateStrokes(recoloredStrokes)
        objectWillChange.send()
    }

    func removeSelectionPaths() throws {
        guard let selection = selection else {
            throw SelectionModifyError.noSelection
        }
        removePaths(selection)
        withAnimation { self.selection = nil }
    }

    func removePaths(_ removeSet: Set<Int>) {
        canvas?.removeStrokes(removeSet)
    }

    func startConversion(image: UIImage) async {
        guard let centerScreen = await canvas?.getCenterScreenCanvasPosition() else { return }
        let conversion = ImageConversion(image: image, position: centerScreen)
        conversion.convert()
        imageConversion = conversion
        imageCancellable = conversion.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        DispatchQueue.main.async {
            withAnimation {
                self.currentTool = .placePhoto
            }
        }
    }

    func placeImage() {
        guard let imageConversion = imageConversion else { return }
        let imagePaths = imageConversion.getStrokes()
        addStrokes(strokes: imagePaths)
        withAnimation { self.currentTool = .pen }
        self.imageConversion = nil
    }

    private func handleToolChange(newTool: CanvasTool) {
        Task { @MainActor in
            if newTool != .selection {
                self.selection = nil
            }
            if newTool != .pen {
                withAnimation { self.isShowingPenColorPicker = false }
            }
        }
    }

    private func handleSelectionChange() {
        Task { @MainActor in
            withAnimation { self.isShowingSelectionColorPicker = false }
        }
    }
}

enum CanvasTool: Equatable {
    case touch, pen, remove, selection, placePhoto
}

enum PhotoMode {
    case welcome, none, cameraScan, library, example
}

enum SelectionModifyError: Error {
    case noSelection
}

enum SemanticColor: CaseIterable, Comparable {
    case primary, gray, red, orange, yellow, green, blue, purple

    var lightColor: UIColor {
        switch self {
        case .primary:
            return #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        case .gray:
            return #colorLiteral(red: 0.5568627451, green: 0.5568627451, blue: 0.5764705882, alpha: 1)
        case .red:
            return #colorLiteral(red: 0.9833723903, green: 0.1313590407, blue: 0.1335203946, alpha: 1)
        case .orange:
            return #colorLiteral(red: 0.999529779, green: 0.5594156384, blue: 0, alpha: 1)
        case .yellow:
            return #colorLiteral(red: 0.9696072936, green: 0.8020537496, blue: 0, alpha: 1)
        case .green:
            return #colorLiteral(red: 0.3882352941, green: 0.7921568627, blue: 0.337254902, alpha: 1)
        case .blue:
            return #colorLiteral(red: 0.03155988827, green: 0.4386033714, blue: 0.9659433961, alpha: 1)
        case .purple:
            return #colorLiteral(red: 0.6174378395, green: 0.2372990549, blue: 0.8458326459, alpha: 1)
        }
    }

    var color: UIColor {
        Self.adaptiveInvertedBrightness(color: lightColor)
    }

    static func adaptiveInvertedBrightness(color: UIColor) -> UIColor {
        let lightMode = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let darkMode = invertedBrightnessColor(color: lightMode)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkMode : lightMode
        }
    }

    static func invertedBrightnessColor(color: UIColor) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(hue: hue, saturation: saturation, brightness: 1 - brightness, alpha: alpha)
    }

    var pencilKitColor: UIColor {
        lightColor
    }

    func name(isDark: Bool) -> String {
        switch self {
        case .primary:
            return isDark ? "White" : "Black"
        case .gray:
            return "Gray"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .purple:
            return "Purple"
        }
    }
}

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
        guard let paths = paths else { return [] }
        return paths.map { points, color in
            let transformedPoints = points.map { point in
                PKStrokePoint(location: point.applying(transform), timeOffset: 0, size: CGSize(width: 3, height: 3), opacity: 1, force: 2, azimuth: 0, altitude: 0)
            }
            let path = PKStrokePath(controlPoints: transformedPoints, creationDate: Date())
            return PKStroke(ink: PKInk(.pen, color: color), path: path, transform: .identity, mask: nil)
        }
    }
}
