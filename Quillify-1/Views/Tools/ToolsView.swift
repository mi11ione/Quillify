import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel = ToolsViewModel()

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

                    LazyVGrid(columns: viewModel.toolColumns, alignment: .leading, spacing: 5) {
                        ForEach(viewModel.tools) { tool in
                            VStack(alignment: .leading) {
                                if tool.imageName == "pencil.tip" {
                                    ZStack {
                                        Image(systemName: tool.imageName)
                                            .font(viewModel.toolFont)
                                            .foregroundColor(.secondary)

                                        Image(systemName: tool.imageName)
                                            .font(viewModel.toolFont)
                                            .foregroundColor(tool.color)
                                            .mask(VStack {
                                                Rectangle()
                                                    .foregroundColor(.white)
                                                    .frame(height: 34)

                                                Spacer()
                                            })
                                    }
                                    .frame(width: 100)
                                    .padding(.bottom, 20)
                                } else {
                                    Image(systemName: tool.imageName)
                                        .font(viewModel.toolFont)
                                        .foregroundColor(tool.color ?? .secondary)
                                        .frame(width: 100)
                                        .padding(.bottom, 20)
                                }

                                Text(tool.title)
                                    .font(.title2).bold()
                                    .foregroundColor(.accentColor)
                                    .padding(.bottom, 3)

                                Text(tool.description)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                            }
                            .padding(.bottom, 40)
                        }
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
