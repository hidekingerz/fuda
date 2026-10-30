import SwiftUI

struct PanelView: View {
    @ObservedObject var viewModel: PanelViewModel
    @FocusState private var searchFocused: Bool
    @AppStorage(PanelTextSize.defaultsKey) private var textSize: PanelTextSize = .large

    private var scale: CGFloat { textSize.scale }

    var body: some View {
        Group {
            switch viewModel.mode {
            case .list:
                listBody
            case .form(let snippet):
                SnippetFormView(viewModel: viewModel, editing: snippet)
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
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            if viewModel.results.isEmpty {
                emptyState
            } else {
                resultList
            }
            Divider()
            footer
        }
        .onAppear { searchFocused = true }
        .onChange(of: viewModel.mode) { _, mode in
            if mode == .list { searchFocused = true }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("履歴とスニペットを検索", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16 * scale))
                .focused($searchFocused)
                .onSubmit { viewModel.confirmSelection() }
            Menu {
                Picker("並び順", selection: $viewModel.sortOrder) {
                    ForEach(PanelSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("並び順: \(viewModel.sortOrder.label)")
            Button {
                viewModel.beginNewSnippet()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("スニペットを追加 (⌘N)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28 * scale))
                .foregroundStyle(.tertiary)
            Text(viewModel.query.isEmpty ? "履歴はまだありません" : "一致する項目がありません")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, entry in
                        PanelRow(
                            entry: entry,
                            isSelected: index == viewModel.selectedIndex,
                            isKeywordMatch: viewModel.keywordMatches.contains(entry.id),
                            usageCount: viewModel.usageCount(for: entry)
                        )
                            .id(entry.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                viewModel.confirmSelection()
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
        switch entry {
        case .history:
            Button(entry.isPinned ? "ピンを外す" : "ピン留め") { viewModel.togglePinned(entry) }
            Button("削除", role: .destructive) { viewModel.delete(entry) }
        case .snippet(let snippet):
            Button("編集") { viewModel.beginEdit(snippet) }
            Button("削除", role: .destructive) { viewModel.delete(entry) }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(key: "↑↓", label: "選択")
            KeyHint(key: "⏎", label: "貼り付け")
            KeyHint(key: "⌘N", label: "スニペット追加")
            KeyHint(key: "⌘E", label: "編集")
            KeyHint(key: "esc", label: "閉じる")
            Spacer()
            if viewModel.sortOrder != .newest {
                Text(viewModel.sortOrder.label)
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

private struct PanelRow: View {
    @Environment(\.panelTextScale) private var scale
    let entry: PanelEntry
    let isSelected: Bool
    let isKeywordMatch: Bool
    let usageCount: Int

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: (entry.isImage ? 48 : 16) * scale)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "(空白)" : entry.title)
                    .lineLimit(1)
                    .font(.system(size: 13 * scale, weight: entry.isSnippet ? .semibold : .regular))
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            Spacer()
            if usageCount > 0 {
                Text("×\(usageCount)")
                    .font(.system(size: 10 * scale, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .help("貼り付け回数")
            }
            if !entry.isPastable {
                Text("見つかりません")
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            if entry.isSnippet {
                Text(badgeText)
                    .font(.system(size: 10 * scale, weight: isKeywordMatch ? .semibold : .regular))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(badgeBackground))
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .opacity(entry.isPastable ? 1 : 0.5)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : .clear)
        )
    }
}

private extension PanelRow {
    var badgeText: String {
        if isKeywordMatch, let keyword = entry.keyword { return "keyword: \(keyword)" }
        if let keyword = entry.keyword { return keyword }
        return "snippet"
    }

    var badgeBackground: Color {
        if isSelected { return .white.opacity(0.25) }
        return isKeywordMatch ? Color.orange.opacity(0.3) : Color.accentColor.opacity(0.15)
    }

    @ViewBuilder
    var icon: some View {
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
            Image(systemName: entry.isSnippet ? "text.quote" : (entry.isPinned ? "pin.fill" : "doc.on.clipboard"))
                .foregroundStyle(isSelected ? .white : .secondary)
        }
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
