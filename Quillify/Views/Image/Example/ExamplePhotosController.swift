import UIKit
import SwiftUI
import Combine

class ExamplePhotosController: UIViewController {
    var state: WindowState
    var picker: UIHostingController<ExamplePhotosNavigationView>?
    var cancellable: AnyCancellable? = nil

    init(windowState: WindowState) {
        self.state = windowState
        super.init(nibName: nil, bundle: nil)
        self.cancellable = state.$photoMode.sink { [weak self] mode in
            guard let self = self else { return }
            if mode == .example {
                let picker = UIHostingController(rootView: ExamplePhotosNavigationView(windowState: windowState))
                self.picker = picker
                self.present(picker, animated: true)
            } else {
                self.picker?.dismiss(animated: true)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
