import SwiftUI

/// 札の色。アプリアイコンの藍と生成りに合わせる。
enum FudaColor {
    /// アイコン背景のグラデーション上端の藍。ダークモードでも沈まない明るさにする。
    static let indigo = Color(red: 0.24, green: 0.30, blue: 0.52)
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.85)
}

struct PanelView: View {
    @ObservedObject var viewModel: PanelViewModel
    @FocusState private var searchFocused: Bool
    @AppStorage(PanelTextSize.defaultsKey) private var textSize: PanelTextSize = .large
    @AppStorage(ConfirmAction.defaultsKey) private var enterAction: ConfirmAction = .default

    private var scale: CGFloat { textSize.scale }

    var body: some View {
        Group {
            switch viewModel.mode {
            case .list:
                listBody
            case .form(let snippet, let prefill):
                SnippetFormView(viewModel: viewModel, editing: snippet, prefill: prefill)
            }
        }
        .frame(width: PanelTextSize.baseWidth * scale, height: PanelTextSize.baseHeight * scale)
        .background(.regularMaterial)
        .environment(\.panelTextScale, scale)
    }

    private var listBody: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.otherTabMatchCount > 0 {
                otherTabHint
            }
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            content
            Divider()
            footer
        }
        .onAppear { searchFocused = true }
        .onChange(of: viewModel.mode) { _, mode in
            if mode == .list { searchFocused = true }
        }
        .onChange(of: viewModel.tab) { _, _ in searchFocused = true }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(spacing: 10) {
            TabSwitcher(selection: $viewModel.tab)
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(viewModel.tab == .history ? "履歴を検索" : "スニペットを検索", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16 * scale))
                .focused($searchFocused)
                .onSubmit { viewModel.confirmSelection() }
            Menu {
                Picker("並び順", selection: Binding(
                    get: { viewModel.sortOrder },
                    set: { viewModel.sortOrder = $0 }
                )) {
                    ForEach(viewModel.tab.sortOrders) { order in
                        Text(order.label(in: viewModel.tab)).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("並び順: \(viewModel.sortOrder.label(in: viewModel.tab))")
            if viewModel.tab == .snippets {
                Button {
                    viewModel.beginNewSnippet()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("スニペットを追加 (⌘N)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// 今のモードで見つからなくても、もう一方にあることを知らせる。
    private var otherTabHint: some View {
        Button {
            viewModel.toggleTab()
        } label: {
            HStack(spacing: 6) {
                Text("\(viewModel.tab.other.label)\(viewModel.results.isEmpty ? "に" : "にも") \(viewModel.otherTabMatchCount) 件あります")
                KeyHint(key: "⇥", label: "切り替え")
                Spacer()
            }
            .font(.system(size: 11 * scale))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(FudaColor.indigo.opacity(0.08))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 本体

    @ViewBuilder
    private var content: some View {
        switch viewModel.tab {
        case .history:
            if viewModel.results.isEmpty {
                emptyState
            } else {
                resultList(doubleClickToConfirm: false) { index, entry in
                    HistoryRow(
                        entry: entry,
                        isSelected: index == viewModel.selectedIndex,
                        usageCount: viewModel.usageCount(for: entry)
                    )
                }
            }
        case .snippets:
            HStack(spacing: 0) {
                Group {
                    if viewModel.results.isEmpty {
                        emptyState
                    } else {
                        resultList(doubleClickToConfirm: true) { index, entry in
                            SnippetRow(
                                entry: entry,
                                isSelected: index == viewModel.selectedIndex,
                                isKeywordMatch: viewModel.keywordMatches.contains(entry.id)
                            )
                        }
                    }
                }
                .frame(width: PanelTextSize.baseWidth * scale * 0.4)
                Divider()
                SnippetPreview(
                    entry: viewModel.selectedEntry,
                    usageCount: viewModel.selectedEntry.map(viewModel.usageCount(for:)) ?? 0
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: viewModel.tab == .history ? "doc.on.clipboard" : "text.quote")
                .font(.system(size: 28 * scale))
                .foregroundStyle(.tertiary)
            Text(emptyMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    private var emptyMessage: String {
        if !viewModel.query.isEmpty { return "一致する項目がありません" }
        switch viewModel.tab {
        case .history: return "コピーした内容がここに並びます"
        case .snippets: return "⌘N でスニペットを追加します"
        }
    }

    /// スニペットはプレビューを見て選ぶので、クリックで選択、ダブルクリックで確定にする。
    private func resultList<Row: View>(
        doubleClickToConfirm: Bool,
        @ViewBuilder row: @escaping (Int, PanelEntry) -> Row
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, entry in
                        row(index, entry)
                            .id(entry.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: doubleClickToConfirm ? 2 : 1) {
                                viewModel.selectedIndex = index
                                viewModel.confirmSelection()
                            }
                            .onTapGesture {
                                viewModel.selectedIndex = index
                            }
                            .contextMenu { contextMenu(for: entry) }
                    }
                }
                .padding(6)
            }
            .onChange(of: viewModel.selectedIndex) { _, index in
                guard viewModel.results.indices.contains(index) else { return }
                proxy.scrollTo(viewModel.results[index].id, anchor: .center)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for entry: PanelEntry) -> some View {
        Button("貼り付け") { viewModel.confirm(entry, action: .paste) }
        Button("コピー") { viewModel.confirm(entry, action: .copyOnly) }
        Divider()
        switch entry {
        case .history(let item):
            if item.type == .text {
                Button("スニペットにする") { viewModel.beginSnippet(from: entry) }
            }
            Button(entry.isPinned ? "ピンを外す" : "ピン留め") { viewModel.togglePinned(entry) }
            Button("削除", role: .destructive) { viewModel.delete(entry) }
        case .snippet(let snippet):
            Button("編集") { viewModel.beginEdit(snippet) }
            Button("削除", role: .destructive) { viewModel.delete(entry) }
        }
    }

    // MARK: - フッター

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(key: "⏎", label: enterAction.shortLabel)
            KeyHint(key: "⇧⏎", label: enterAction.alternate.shortLabel)
            if viewModel.tab == .snippets {
                KeyHint(key: "⌘N", label: "追加")
                KeyHint(key: "⌘E", label: "編集")
            }
            KeyHint(key: "⇥", label: viewModel.tab.other.label)
            KeyHint(key: "esc", label: "閉じる")
            Spacer()
            if viewModel.sortOrder != viewModel.tab.defaultSort {
                Text(viewModel.sortOrder.label(in: viewModel.tab))
                    .foregroundStyle(.secondary)
            }
            Text("\(viewModel.results.count) 件")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11 * scale))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - モード切り替え

/// 履歴とスニペットを切り替えるタブ。選択中は札の藍と生成りで塗る。
private struct TabSwitcher: View {
    @Environment(\.panelTextScale) private var scale
    @Binding var selection: PanelTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PanelTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    selection = tab
                } label: {
                    Text(tab.label)
                        .font(.system(size: 12 * scale, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? FudaColor.cream : Color.secondary)
                        .padding(.horizontal, 8 * scale)
                        .padding(.vertical, 3 * scale)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? FudaColor.indigo : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary))
        .help("⇥ で切り替え")
    }
}

// MARK: - 行

private struct HistoryRow: View {
    @Environment(\.panelTextScale) private var scale
    let entry: PanelEntry
    let isSelected: Bool
    let usageCount: Int

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: (entry.isImage ? 48 : 16) * scale)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "(空白)" : entry.title)
                    .lineLimit(1)
                    .font(.system(size: 13 * scale))
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(secondaryStyle)
                }
            }
            Spacer()
            if usageCount > 0 {
                Text("×\(usageCount)")
                    .font(.system(size: 10 * scale, design: .rounded))
                    .foregroundStyle(secondaryStyle)
                    .help("貼り付け回数")
            }
            if !entry.isPastable {
                Text("見つかりません")
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(secondaryStyle)
            }
            if let createdAt = entry.historyItem?.createdAt {
                Text(RelativeTime.text(for: createdAt))
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(secondaryStyle)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .opacity(entry.isPastable ? 1 : 0.5)
        .rowBackground(isSelected: isSelected)
    }

    private var secondaryStyle: Color {
        isSelected ? .white.opacity(0.8) : .secondary
    }

    @ViewBuilder
    private var icon: some View {
        if let item = entry.historyItem, item.type == .file, let url = item.fileURLs.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 16 * scale, height: 16 * scale)
        } else if let thumbnail = entry.historyItem?.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48 * scale, height: 32 * scale)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.quaternary))
        } else {
            Image(systemName: entry.isPinned ? "pin.fill" : "doc.on.clipboard")
                .foregroundStyle(isSelected ? .white : .secondary)
        }
    }
}

private struct SnippetRow: View {
    @Environment(\.panelTextScale) private var scale
    let entry: PanelEntry
    let isSelected: Bool
    let isKeywordMatch: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(entry.title)
                .lineLimit(1)
                .font(.system(size: 13 * scale, weight: .semibold))
            Spacer(minLength: 4)
            if let keyword = entry.keyword {
                KeywordBadge(keyword: keyword, isSelected: isSelected, isMatch: isKeywordMatch)
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .rowBackground(isSelected: isSelected)
    }
}

private struct KeywordBadge: View {
    @Environment(\.panelTextScale) private var scale
    let keyword: String
    let isSelected: Bool
    let isMatch: Bool

    var body: some View {
        Text(keyword)
            .font(.system(size: 10 * scale, weight: isMatch ? .semibold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(background))
            .help(isMatch ? "キーワードが一致" : "キーワード")
    }

    private var background: Color {
        if isSelected { return .white.opacity(0.25) }
        return isMatch ? Color.orange.opacity(0.3) : Color.accentColor.opacity(0.15)
    }
}

/// 選択中のスニペットの中身。貼る前に確かめられるようにする。
private struct SnippetPreview: View {
    @Environment(\.panelTextScale) private var scale
    let entry: PanelEntry?
    let usageCount: Int

    var body: some View {
        if case .snippet(let snippet)? = entry {
            VStack(alignment: .leading, spacing: 8) {
                Text(snippet.title)
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 10) {
                    if let keyword = snippet.keyword {
                        Label(keyword, systemImage: "character.cursor.ibeam")
                    }
                    Text("更新 \(RelativeTime.shortDate(snippet.updatedAt))")
                    if usageCount > 0 {
                        Text("\(usageCount) 回使用")
                    }
                }
                .font(.system(size: 11 * scale))
                .foregroundStyle(.secondary)
                Divider()
                ScrollView {
                    Text(snippet.content)
                        .font(.system(size: 12 * scale, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("スニペットを選ぶと内容を表示します")
                .font(.system(size: 12 * scale))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension View {
    func rowBackground(isSelected: Bool) -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : .clear)
            )
    }
}

private struct KeyHint: View {
    @Environment(\.panelTextScale) private var scale
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(.quaternary))
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
