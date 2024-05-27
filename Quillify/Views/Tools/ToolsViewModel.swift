import SwiftUI

struct Tool: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let color: Color?
}

class ToolsViewModel: ObservableObject {
    @Published var tools: [Tool] = [
        Tool(imageName: "hand.point.up", title: "Касание", color: .secondary),
        Tool(imageName: "pencil.tip", title: "Ручка", color: .red),
        Tool(imageName: "photo", title: "Фото", color: .secondary),
        Tool(imageName: "scribble", title: "Ластик", color: .secondary),
        Tool(imageName: "lasso", title: "Лассо", color: .secondary),
    ]

    let toolFont: Font = .system(size: 80)
    let toolColumns = [GridItem(.adaptive(minimum: 150))]
}
