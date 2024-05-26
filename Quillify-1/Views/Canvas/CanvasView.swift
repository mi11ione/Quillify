//
//  CanvasView.swift
//  Quillify
//
//  Created by mi11ion on 19/3/24.
//

import SwiftUI

struct CanvasView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState

    func makeUIViewController(context _: Context) -> UIViewController {
        Canvas(state: windowState)
    }

    func updateUIViewController(_: UIViewController, context _: Context) {
        // ignore
    }
}
