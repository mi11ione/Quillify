import SwiftUI

class ExamplePhotos {
    static var photos: [UIImage] = [
        UIImage(named: "example1.heic"),
        UIImage(named: "example2.jpg"),
        UIImage(named: "example3.jpg"),
    ].compactMap { $0 }
}
