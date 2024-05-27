import Combine
import CoreGraphics
import PDFKit
import PencilKit
import SwiftUI

class Canvas: UIViewController, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    @Environment(\.colorScheme) var colorScheme
    static var canvasSize: CGSize = .init(width: 1200, height: 1200)
    var state: WindowState

    var didScrollToOffset = false
    var cancellables = Set<AnyCancellable>()

    var selectionGestureRecognizer: UIPanGestureRecognizer?
    var selectMinX: CGFloat?
    var selectMaxX: CGFloat?
    var selectMinY: CGFloat?
    var selectMaxY: CGFloat?

    var selectRect: CGRect? {
        guard let selectMinX,
              let selectMaxX,
              let selectMinY,
              let selectMaxY else { return nil }
        return CGRect(x: selectMinX, y: selectMinY,
                      width: abs(selectMaxX - selectMinX), height: abs(selectMaxY - selectMinY))
    }

    var imageRenderView: ImageRenderView?

    let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.backgroundColor = .white
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
            guard let self else { return }
            switch tool {
            case .pen:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: self.state.currentColor.pencilKitColor)
            case .placePhoto:
                self.imageRenderView?.isUserInteractionEnabled = true
                self.canvasView.isUserInteractionEnabled = false
                self.canvasView.drawingGestureRecognizer.isEnabled = false
                self.canvasView.tool = PKInkingTool(.pen, color: self.state.currentColor.pencilKitColor)
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
                self.canvasView.tool = PKInkingTool(.pen, color: self.state.currentColor.pencilKitColor)
                self.canvasView.drawingGestureRecognizer.isEnabled = false
            }
        }
        cancellables.insert(changeToolCancellable)

        let colorCancellable = state.$currentColor.sink { [weak self] color in
            guard let self else { return }
            if self.state.currentTool == .pen {
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

        updateCanvasBackgroundColor()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToInitialOffsetIfRequired()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateCanvasBackgroundColor()
        }
    }

    private func scrollToInitialOffsetIfRequired() {
        if !didScrollToOffset {
            let offsetX = (canvasView.contentSize.width - canvasView.frame.width) / 2
            let offsetY = (canvasView.contentSize.height - canvasView.frame.height) / 2
            canvasView.contentOffset = CGPoint(x: offsetX, y: offsetY)
            didScrollToOffset = true
        }
    }

    private func updateCanvasBackgroundColor() {
        if traitCollection.userInterfaceStyle == .dark {
            canvasView.backgroundColor = .black
        } else {
            canvasView.backgroundColor = .white
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
        guard let selectMinX,
              let selectMaxX,
              let selectMinY,
              let selectMaxY
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
            if let selectRect {
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
