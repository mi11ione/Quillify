//
//  ToolsView.swift
//  Quillify-1
//
//  Created by mi11ion on 19/3/24.
//

import SwiftUI

struct LearnToolsView: View {
    let toolFont: Font = {
        Font.system(size: 80)
    }()
    
    let toolColumns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        VStack {
            Spacer().frame(height: 100)
            
            HStack {
                Spacer()
            }
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Ваши инструменты").font(.title)
                        .bold()
                        .padding(.bottom, 40)
                    
                    LazyVGrid(columns: toolColumns, alignment: .leading, spacing: 5) {
                        VStack(alignment: .leading) {
                            Image(systemName: "hand.point.up").font(toolFont)
                                .foregroundColor(.secondary)
                                .frame(width: 100)
                                .padding(.bottom, 20)
                            Text("Касание")
                                .font(.title2).bold()
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 3)
                            Text("Используйте аккуратно ок")
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                        
                        VStack(alignment: .leading) {
                            ZStack {
                                Image(systemName: "pencil.tip")
                                    .font(toolFont)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "pencil.tip")
                                    .font(toolFont)
                                    .foregroundColor(Color.red)
                                    .mask(VStack{
                                        Rectangle()
                                            .foregroundColor(.white)
                                            .frame(height: 34)
                                        
                                        Spacer()
                                    })
                            }
                            .frame(width: 100)
                            .padding(.bottom, 20)
                            
                            Text("Ручка")
                                .font(.title2).bold()
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 3)
                            
                            Text("Нажмите на ручку, чтобы выбрать цвет")
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                        
                        VStack(alignment: .leading) {
                            Image(systemName: "photo").font(toolFont)
                                .foregroundColor(.secondary)
                                .frame(width: 100)
                                .padding(.bottom, 20)
                            Text("Добавить фото")
                                .font(.title2).bold()
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 3)
                            Text("Конвертируйте фото в цифровые чернила")
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                        
                        VStack(alignment: .leading) {
                            ZStack{
                                Image(systemName: "scribble")
                                    .font(toolFont)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "line.diagonal")
                                    .font(toolFont)
                                    .foregroundColor(Color.red)
                            }
                            .frame(width: 100)
                            .padding(.bottom, 20)
                            
                            Text("Ластик")
                                .font(.title2).bold()
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 3)
                            
                            Text("Стирает вашу красоту, с этим и так все понятно")
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                        
                        VStack(alignment: .leading) {
                            Image(systemName: "lasso").font(toolFont)
                                .foregroundColor(.secondary)
                                .frame(width: 100)
                                .padding(.bottom, 20)
                            
                            Text("Лассо")
                                .font(.title2).bold()
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 3)
                            
                            Text("Хотите передвинуть, удалить или поменять цвет?")
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                    }
                }
                .lineSpacing(10)
                .frame(maxWidth: 600)
                .padding()
                
                Spacer().frame(height: 200)
                Spacer()
            }
        }
    }
}
