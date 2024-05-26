import Combine
import SwiftUI
import VisionKit

class CameraScan: UIViewController {
    private var state: WindowState
    private var cancellable: AnyCancellable? = nil
    private var documentScanner: VNDocumentCameraViewController? = nil
    private var viewModel: CameraScanViewModel

    init(windowState: WindowState, viewModel: CameraScanViewModel) {
        state = windowState
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }

    private func setupBindings() {
        cancellable = state.$photoMode.sink { [weak self] mode in
            self?.handlePhotoModeChange(mode: mode)
        }
    }

    private func handlePhotoModeChange(mode: PhotoMode) {
        if mode == .cameraScan {
            presentDocumentScanner()
        } else {
            dismissDocumentScanner()
        }
    }

    private func presentDocumentScanner() {
        let documentViewController = VNDocumentCameraViewController()
        documentViewController.delegate = viewModel
        documentScanner = documentViewController
        present(documentViewController, animated: true)
    }

    private func dismissDocumentScanner() {
        documentScanner?.dismiss(animated: true)
    }
}
