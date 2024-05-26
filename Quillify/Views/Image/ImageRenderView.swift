import PencilKit
import Combine
import SwiftUI
import CoreGraphics

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
