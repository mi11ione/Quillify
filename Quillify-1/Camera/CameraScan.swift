//
//  CameraScan.swift
//  Quillify
//
//  Created by mi11ion on 17/4/24.
//

import Combine
import VisionKit

class CameraScan: UIViewController, VNDocumentCameraViewControllerDelegate {
    var state: WindowState
    var cancellable: AnyCancellable? = nil
    var documentScanner: VNDocumentCameraViewController? = nil

    init(windowState: WindowState) {
        state = windowState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = state.$photoMode.sink(receiveValue: { [weak self] mode in
            guard let self = self else { return }
            if mode == .cameraScan {
                let documentViewController = VNDocumentCameraViewController()
                documentViewController.delegate = self
                self.documentScanner = documentViewController
                self.present(documentViewController, animated: true)
            } else {
                self.documentScanner?.dismiss(animated: true)
            }
        })
    }

    func documentCameraViewController(_: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        if scan.pageCount > 0 {
            let image = scan.imageOfPage(at: 0)
            Task { @MainActor in
                await self.state.startConversion(image: image)
            }
        }
        documentScanner?.dismiss(animated: true)
    }

    func documentCameraViewControllerDidCancel(_: VNDocumentCameraViewController) {
        documentScanner?.dismiss(animated: true)
    }

    func documentCameraViewController(_: VNDocumentCameraViewController, didFailWithError _: Error) {
        documentScanner?.dismiss(animated: true)
    }
}
