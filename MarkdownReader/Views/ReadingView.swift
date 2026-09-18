import SwiftUI

struct ReadingView: View {
    let blocks: [MarkdownBlock]
    let fontSize: Double
    let serif: Bool
    let query: String
    let toggleTask: (Int) -> Void
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(blocks) { block in
                blockView(block)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .background(!query.isEmpty && block.text.localizedCaseInsensitiveContains(query) ? Color.yellow.opacity(0.2) : .clear)
                    .id(block.id)
            }
        }
        .font(.system(size: fontSize, design: serif ? .serif : .default))
        .lineSpacing(7)
        .textSelection(.enabled)
        .frame(maxWidth: 740, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }
    private func inline(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
    }
    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level):
            inline(block.text)
                .font(.system(size: fontSize + Double(max(0, 4 - level)) * 7, weight: .bold, design: serif ? .serif : .default))
                .padding(.top, level == 1 ? 4 : 16)
                .accessibilityAddTraits(.isHeader)
        case .paragraph:
            inline(block.text)
        case .quote:
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 2).fill(.tint).frame(width: 3)
                inline(block.text).foregroundStyle(.secondary).italic().padding(.vertical, 8)
            }.fixedSize(horizontal: false, vertical: true)
        case .code(let language):
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(language.isEmpty ? "代码" : language.uppercased()).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    ShareLink(item: block.text) { Image(systemName: "square.and.arrow.up") }.labelStyle(.iconOnly).help("分享代码")
                }
                ScrollView(.horizontal) { Text(block.text).font(.system(size: fontSize - 2, design: .monospaced)).fixedSize(horizontal: true, vertical: false) }
            }.padding(18).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
        case .list(let marker):
            HStack(alignment: .firstTextBaseline, spacing: 12) { Text(marker).foregroundStyle(.tint).frame(minWidth: 20); inline(block.text) }
        case .task(let checked):
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button { toggleTask(block.id) } label: { Image(systemName: checked ? "checkmark.circle.fill" : "circle").foregroundStyle(checked ? Color.accentColor : Color.secondary) }
                    .buttonStyle(.plain).accessibilityLabel(checked ? "标记为未完成：\(block.text)" : "完成：\(block.text)")
                inline(block.text).strikethrough(checked).foregroundStyle(checked ? .secondary : .primary)
            }
        case .divider: Divider().padding(.vertical, 12)
        case .table(let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        GridRow {
                            ForEach(0..<(rows.map(\.count).max() ?? 0), id: \.self) { column in
                                inline(column < row.count ? row[column] : "").fontWeight(rowIndex == 0 ? .semibold : .regular)
                            }
                        }
                        if rowIndex == 0 { Divider().gridCellUnsizedAxes(.horizontal) }
                    }
                }.padding(18)
            }.background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
