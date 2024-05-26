import Combine
import VisionKit

class CameraScanViewModel: NSObject, ObservableObject, VNDocumentCameraViewControllerDelegate {
    private var state: WindowState

    init(windowState: WindowState) {
        self.state = windowState
        super.init()
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        if scan.pageCount > 0 {
            let image = scan.imageOfPage(at: 0)
            Task { @MainActor in
                await state.startConversion(image: image)
            }
        }
        controller.dismiss(animated: true)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
    }
}
