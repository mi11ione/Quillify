//
//  CameraScanView.swift
//  Quillify-1
//
//  Created by mi11ion on 17/4/24.
//

import SwiftUI

struct CameraScanView: UIViewControllerRepresentable {
    typealias UIViewControllerType = CameraScan
    @ObservedObject var windowState: WindowState
    
    func makeUIViewController(context: Context) -> CameraScan {
        CameraScan(windowState: windowState)
    }
    
    func updateUIViewController(_ uiViewController: CameraScan, context: Context) {
        // ignore
    }
}
