import SwiftUI

/// パネル内のスニペット登録・編集フォーム。
struct SnippetFormView: View {
    @ObservedObject var viewModel: PanelViewModel
    let editing: Snippet?
    /// 履歴から作るときの初期内容。
    let prefill: String?

    @State private var title: String
    @State private var content: String
    @State private var keyword: String
    @FocusState private var titleFocused: Bool
    @Environment(\.panelTextScale) private var scale

    init(viewModel: PanelViewModel, editing: Snippet?, prefill: String? = nil) {
        self.viewModel = viewModel
        self.editing = editing
        self.prefill = prefill
        _title = State(initialValue: editing?.title ?? prefill.map { String($0.firstLine.prefix(40)) } ?? "")
        _content = State(initialValue: editing?.content ?? prefill ?? "")
        _keyword = State(initialValue: editing?.keyword ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
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

    private var heading: String {
        if editing != nil { return "スニペットを編集" }
        return prefill == nil ? "スニペットを追加" : "履歴からスニペットを作成"
    }
}
