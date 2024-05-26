import SwiftUI

struct Tool: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
    let color: Color?
}

class ToolsViewModel: ObservableObject {
    @Published var tools: [Tool] = [
        Tool(imageName: "hand.point.up", title: "Касание", description: "Используйте аккуратно ок", color: .secondary),
        Tool(imageName: "pencil.tip", title: "Ручка", description: "Нажмите на ручку, чтобы выбрать цвет", color: .red),
        Tool(imageName: "photo", title: "Добавить фото", description: "Конвертируйте фото в цифровые чернила", color: .secondary),
        Tool(imageName: "scribble", title: "Ластик", description: "Стирает вашу красоту, все понятно", color: .secondary),
        Tool(imageName: "lasso", title: "Лассо", description: "Незаменимая, крутая вещь", color: .secondary),
    ]

    let toolFont: Font = .system(size: 80)
    let toolColumns = [GridItem(.adaptive(minimum: 150))]
}
