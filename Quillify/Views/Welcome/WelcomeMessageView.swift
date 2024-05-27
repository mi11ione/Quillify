import SwiftUI

struct WelcomeMessageView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        VStack {
            HStack {
                Spacer()
            }

            VStack {
                Spacer()

                Image("Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .mask { RoundedRectangle(cornerRadius: 40, style: .continuous) }
                    .accessibilityLabel(Text("App Icon"))
                    .padding()
                    .padding(.vertical, 40)

                VStack(alignment: .leading) {
                    Text("Quillify").font(.largeTitle)
                        .bold()
                        .padding(.bottom)

                    Text(welcomeMessage)
                        .font(fontForCurrentDevice())
                }
                .lineSpacing(10)
                .frame(maxWidth: 600)
                .padding()

                Spacer().frame(height: 200)
                Spacer()
            }
        }
    }

    private func fontForCurrentDevice() -> Font {
        horizontalSizeClass == .compact ? .body : .title2
    }

    private var welcomeMessage: String {
        """
        Добро пожаловать в самое крутое приложение🆒\n
        Quillify позволяет вам преобразовать изображения с рукописным текстом или линейными рисунками в векторные объекты!
        """
    }
}
