import SwiftUI

/// パネル内のスニペット登録・編集フォーム。
struct SnippetFormView: View {
    @ObservedObject var viewModel: PanelViewModel
    let editing: Snippet?

    @State private var title: String
    @State private var content: String
    @State private var keyword: String
    @FocusState private var titleFocused: Bool
    @Environment(\.panelTextScale) private var scale

    init(viewModel: PanelViewModel, editing: Snippet?) {
        self.viewModel = viewModel
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _content = State(initialValue: editing?.content ?? "")
        _keyword = State(initialValue: editing?.keyword ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editing == nil ? "スニペットを追加" : "スニペットを編集")
                .font(.system(size: 15 * scale, weight: .semibold))

            TextField("タイトル", text: $title)
                .font(.system(size: 13 * scale))
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            TextField("キーワード（任意）", text: $keyword)
                .font(.system(size: 13 * scale))
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .font(.system(size: 13 * scale, design: .monospaced))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(.red)
            }

            HStack {
                if let editing {
                    Button("削除", role: .destructive) {
                        viewModel.delete(.snippet(editing))
                        viewModel.cancelForm()
                    }
                }
                Spacer()
                Button("キャンセル") { viewModel.cancelForm() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    viewModel.saveSnippet(editing: editing, title: title, content: content, keyword: keyword)
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .onAppear { titleFocused = true }
    }
}
