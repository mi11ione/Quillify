//
//  CanvasView.swift
//  Quillify-1
//
//  Created by mi11ion on 19/3/24.
//

import SwiftUI

struct CanvasView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState
    
    func makeUIViewController(context: Context) -> UIViewController {
        Canvas(state: windowState)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // ignore
    }
}
