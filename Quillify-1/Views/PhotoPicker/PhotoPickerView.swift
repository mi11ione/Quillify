//
//  PhotoPickerView.swift
//  Quillify-1
//
//  Created by mi11ion on 19/3/24.
//

import SwiftUI

struct PhotoPickerView: View {
    @ObservedObject var windowState: WindowState
    
    var body: some View {
        VStack {
            Spacer().frame(height: 100)
            HStack {
                Spacer()
            }
            
            VStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Можно сфоткаться?")
                        .font(.largeTitle)
                        .bold()
                        .padding(.bottom)
                    
                    HStack {
                        Spacer()
                    }
                }
                .lineSpacing(10)
                .frame(maxWidth: 600)
                .padding()
                
                VStack {
                    Button(action: { withAnimation { self.windowState.photoMode = .cameraScan }}) {
                        HStack {
                            Image(systemName: "viewfinder").font(.largeTitle)
                                .frame(width: 50)
                                .padding(.trailing, 5)
                            
                            VStack(alignment: .leading) {
                                Text("Сканирование")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                
                                Text("Наведи камеру на желаемый текст и отсканируй")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            Color(uiColor: .systemGray6)
                        }
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(Text("Сканирование"))
                    .padding(.vertical, 5)
                    
                    Button(action: { withAnimation{self.windowState.photoMode = .library }}) {
                        HStack(alignment: .center) {
                            Image(systemName: "photo.fill").font(.largeTitle)
                                .frame(width: 50)
                                .padding(.trailing, 5)
                            
                            VStack(alignment: .leading) {
                                Text("Галерея")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                
                                Text("Выбери фото из своей галереи")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            Color(uiColor: .systemGray6)
                        }
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(Text("Галерея"))
                    .padding(.vertical, 5)
                    Button(action: { withAnimation{self.windowState.photoMode = .example }}) {
                        
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                                .frame(width: 50)
                                .padding(.trailing, 5)
                            
                            VStack(alignment: .leading) {
                                Text("Демо")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                
                                Text("Выбери фото из предложенных вариантов")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            Color(uiColor: .systemGray6)
                        }
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(Text("Демо"))
                    .padding(.vertical, 5)
                }
                .frame(maxWidth: 600)
                .padding()
                
                Spacer()
                    .frame(height: 200)
                
                Spacer()
            }
        }
    }
}
