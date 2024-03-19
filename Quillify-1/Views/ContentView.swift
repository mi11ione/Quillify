//
//  ContentView.swift
//  Quillify-1
//
//  Created by mi11ion on 19/3/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var windowState = WindowState()
    
    var isShowingWelcome: Bool {
        windowState.photoMode == .welcome
    }
    
    var body: some View {
        ZStack {
            CanvasDrawView(windowState: windowState)
                .disabled(isShowingWelcome)
                .accessibilityHidden(isShowingWelcome)
                .opacity(isShowingWelcome ? 0 : 1)
            
            if isShowingWelcome {
                Rectangle()
                    .foregroundColor(Color(uiColor: UIColor.systemBackground))
                    .ignoresSafeArea()
                    .opacity(isShowingWelcome ? 0 : 1)
                
                WelcomeView(windowState: windowState)
            }
        }
    }
}
