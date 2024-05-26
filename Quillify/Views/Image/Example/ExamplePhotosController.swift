import Combine
import SwiftUI

class ExamplePhotosController: UIViewController {
    var state: WindowState
    var picker: UIHostingController<ExamplePhotosGridView>?
    var cancellable: AnyCancellable? = nil

    init(windowState: WindowState) {
        state = windowState
        super.init(nibName: nil, bundle: nil)
        cancellable = state.$photoMode.sink { [weak self] mode in
            guard let self else { return }
            if mode == .example {
                let picker = UIHostingController(rootView: ExamplePhotosGridView(windowState: windowState))
                self.picker = picker
                present(picker, animated: true)
            } else {
                picker?.dismiss(animated: true)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
