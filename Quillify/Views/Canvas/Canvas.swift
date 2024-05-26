import Combine
import CoreGraphics
import Foundation
import PencilKit
import SwiftUI

class Canvas: UIViewController, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    static var canvasSize: CGSize = .init(width: 10000, height: 10000)
    var state: WindowState

    var didScrollToOffset = false
    var cancellables = Set<AnyCancellable>()

    var selectionGestureRecognizer: UIPanGestureRecognizer?
    var selectMinX: CGFloat?
    var selectMaxX: CGFloat?
    var selectMinY: CGFloat?
    var selectMaxY: CGFloat?

    var selectRect: CGRect? {
        guard let selectMinX = selectMinX,
              let selectMaxX = selectMaxX,
              let selectMinY = selectMinY,
              let selectMaxY = selectMaxY else { return nil }
        return CGRect(x: selectMinX, y: selectMinY,
                      width: abs(selectMaxX - selectMinX), height: abs(selectMaxY - selectMinY))
    }

    var imageRenderView: ImageRenderView?

    let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.backgroundColor = .systemGray6
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.zoomScale = 1
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentSize = Canvas.canvasSize
        canvas.drawingPolicy = UIPencilInteraction.prefersPencilOnlyDrawing ? .default : .anyInput
        return canvas
    }()

    var strokes: [PKStroke] {
        canvasView.drawing.strokes
    }

    init(state: WindowState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
        state.canvas = self
        canvasView.delegate = self
        let changeToolCancellable = state.$currentTool.sink { [weak self] tool in
            guard let self = self else { return }
            switch tool {
            case .pen:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
            case .placePhoto:
                self.imageRenderView?.isUserInteractionEnabled = true
                self.canvasView.isUserInteractionEnabled = false
                self.canvasView.drawingGestureRecognizer.isEnabled = false
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
            case .remove:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKEraserTool(.vector)
            case .selection:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKLassoTool()
            case .touch:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
                self.canvasView.drawingGestureRecognizer.isEnabled = false
            }
        }
        cancellables.insert(changeToolCancellable)

        let colorCancellable = state.$currentColor.sink { [weak self] color in
            guard let self = self else { return }
            if state.currentTool == .pen {
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: color.pencilKitColor)
            }
        }

        cancellables.insert(colorCancellable)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        view.addSubview(canvasView)

        let constraints = [
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        canvasView.addGestureRecognizer(tapGesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)

        let imageRenderView = ImageRenderView(state: state, canvas: canvasView, frame: view.bounds)
        imageRenderView.isUserInteractionEnabled = false
        self.imageRenderView = imageRenderView
        imageRenderView.translatesAutoresizingMaskIntoConstraints = false
        let imageViewConstraints = [
            imageRenderView.topAnchor.constraint(equalTo: view.topAnchor),
            imageRenderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageRenderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageRenderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        view.addSubview(imageRenderView)
        NSLayoutConstraint.activate(imageViewConstraints)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToInitialOffsetIfRequired()
    }

    private func scrollToInitialOffsetIfRequired() {
        if !didScrollToOffset {
            let offsetX = (canvasView.contentSize.width - canvasView.frame.width) / 2
            let offsetY = (canvasView.contentSize.height - canvasView.frame.height) / 2
            canvasView.contentOffset = CGPoint(x: offsetX, y: offsetY)
            didScrollToOffset = true
        }
    }

    @objc
    func handlePan(_ sender: UIPanGestureRecognizer) {
        guard state.currentTool == .selection else {
            selectionOver()
            return
        }

        let point = sender.location(in: canvasView)

        switch sender.state {
        case .began:
            updateSelectRect(point)
        case .changed:
            updateSelectRect(point)
        case .cancelled:
            finishSelection()
        case .ended:
            finishSelection()
        default:
            break
        }
    }

    private func updateSelectRect(_ translatedPoint: CGPoint) {
        guard let selectMinX = selectMinX,
              let selectMaxX = selectMaxX,
              let selectMinY = selectMinY,
              let selectMaxY = selectMaxY
        else {
            selectMinX = translatedPoint.x
            selectMaxX = translatedPoint.x
            selectMinY = translatedPoint.y
            selectMaxY = translatedPoint.y
            return
        }
        self.selectMinX = min(selectMinX, translatedPoint.x)
        self.selectMaxX = max(selectMaxX, translatedPoint.x)
        self.selectMinY = min(selectMinY, translatedPoint.y)
        self.selectMaxY = max(selectMaxY, translatedPoint.y)
    }

    @objc
    func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            withAnimation { self.state.isShowingPenColorPicker = false }
            withAnimation { self.state.selection = nil }
        }
    }

    func getCenterScreenCanvasPosition() async -> CGPoint {
        let contentOffset = canvasView.contentOffset
        return CGPoint(x: contentOffset.x + (view.bounds.width / 2),
                       y: contentOffset.y + (view.bounds.height / 2))
    }

    private func finishSelection() {
        if state.currentTool == .selection {
            if let selectRect = selectRect {
                var selection = Set<Int>()
                for (index, path) in canvasView.drawing.strokes.enumerated() {
                    if selectRect.intersects(path.renderBounds) {
                        selection.insert(index)
                    }
                }
                if !selection.isEmpty {
                    withAnimation { self.state.selection = selection }
                }
                selectionOver()
            }
        }
    }

    private func selectionOver() {
        selectMinX = nil
        selectMaxX = nil
        selectMinY = nil
        selectMaxY = nil
    }

    func addStrokes(_ strokes: [PKStroke]) {
        canvasView.drawing.strokes.append(contentsOf: strokes)
    }

    func updateStrokes(_ strokes: [(Int, PKStroke)]) {
        var indexToStroke = [Int: PKStroke]()
        for (index, stroke) in strokes {
            indexToStroke[index] = stroke
        }

        var newStrokes = canvasView.drawing.strokes
        for index in newStrokes.indices {
            if let stroke = indexToStroke[index] {
                newStrokes[index] = stroke
            }
        }
        canvasView.drawing.strokes = newStrokes
    }

    func removeStrokes(_ strokes: Set<Int>) {
        canvasView.drawing.strokes = canvasView.drawing.strokes.enumerated().filter { index, _ in
            !strokes.contains(index)
        }.map { _, stroke in
            stroke
        }
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }
}

class ImageRenderView: UIView, UIGestureRecognizerDelegate {
    private var state: WindowState
    private var imageScale: CGAffineTransform = .identity
    private var imageTranslation: CGAffineTransform = .identity

    var pinchGesture: UIPinchGestureRecognizer?
    var panGesture: UIPanGestureRecognizer?
    private var cancellables = Set<AnyCancellable>()
    private var canvasView: PKCanvasView

    init(state: WindowState, canvas: PKCanvasView, frame: CGRect) {
        self.state = state
        canvasView = canvas
        super.init(frame: frame)
        backgroundColor = .clear

        let toolChange = state.$currentTool.sink(receiveValue: { [weak self] tool in
            if tool == .touch || tool == .placePhoto {
                self?.panGesture?.isEnabled = true
            } else {
                self?.panGesture?.isEnabled = false
            }
        })

        let stateChange = state.objectWillChange.sink(receiveValue: { [weak self] _ in
            self?.setNeedsDisplay()
        })

        cancellables.insert(toolChange)
        cancellables.insert(stateChange)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self

        pinchGesture = pinch
        addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.allowedScrollTypesMask = [.all]
        panGesture = pan
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func handlePinch(_ sender: UIPinchGestureRecognizer) {
        let transform = CGAffineTransform(scaleX: sender.scale, y: sender.scale)
        let updateScale = {
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = transform
            default:
                break
            }
        }

        let applyScale = {
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = .identity
                self.state.imageConversion?.applyScale(transform: transform)
            default:
                break
            }
        }

        switch sender.state {
        case .began:
            updateScale()
        case .changed:
            updateScale()
        case .cancelled:
            applyScale()
        case .ended:
            applyScale()
        default:
            break
        }
        setNeedsDisplay()
    }

    @objc
    func handlePan(_ sender: UIPanGestureRecognizer) {
        let point = sender.translation(in: self)

        let translation = CGAffineTransform(translationX: point.x, y: point.y)
        let updatePan = {
            let currentTool = self.state.currentTool
            if currentTool == .placePhoto {
                self.imageTranslation = translation
            }
        }

        let applyPan = {
            let currentTool = self.state.currentTool
            if currentTool == .placePhoto {
                self.finishPhotoTranslate(translation)
            }
        }

        switch sender.state {
        case .began:
            updatePan()
        case .changed:
            updatePan()
        case .cancelled:
            applyPan()
        case .ended:
            applyPan()
        default:
            break
        }
        setNeedsDisplay()
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }

    private func finishPhotoTranslate(_ translation: CGAffineTransform) {
        state.imageConversion?.applyTranslate(transform: translation)
        imageTranslation = .identity
    }

    override func draw(_: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        if let imageConversion = state.imageConversion {
            let size = imageConversion.image.size
            var rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            rect = rect.applying(imageConversion.scaleTransform)
            rect = rect.applying(imageScale)
            rect = rect.applying(imageConversion.translateTransform)
            rect = rect.applying(imageTranslation)
            rect = rect.applying(.init(translationX: -canvasView.contentOffset.x, y: -canvasView.contentOffset.y))
            context.saveGState()
            context.translateBy(x: 0, y: rect.origin.y + rect.height)
            context.scaleBy(x: 1, y: -1)
            if let cgImage = imageConversion.image.cgImage {
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: rect.origin.x, y: 0), size: rect.size))
            }
            context.restoreGState()
        }
    }
}
