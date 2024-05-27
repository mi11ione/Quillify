import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel = ToolsViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading) {
            if horizontalSizeClass == .regular {
                Spacer(minLength: 100)
            }
            Text("Ваши инструменты")
                .font(.title)
                .bold()
                .padding(.bottom, 40)

            LazyVGrid(columns: viewModel.toolColumns, alignment: .center, spacing: 50) {
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
                            .padding(.bottom, 30)
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
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: 600)
        .padding()
        .padding(.horizontal, 10)

        Spacer(minLength: 80)
    }
}
