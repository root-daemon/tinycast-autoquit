import SwiftUI

struct AutoQuitPaletteList: View {
    @Environment(\.metrics) private var metrics
    let rows: [AutoQuitPaletteItem]
    let selectedID: String?
    let scroll: ScrollIntent
    let onActivate: (AutoQuitPaletteItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        if let section = row.section {
                            SectionHeader(title: section)
                        }
                        AutoQuitPaletteRow(item: row, selected: row.id == selectedID)
                            .selectionFrame(row.id == selectedID)
                            .contentShape(Rectangle())
                            .onTapGesture { onActivate(row) }
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.vertical, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID, atOrigin: selectedID == rows.first?.id, proxy: proxy)
        }
    }
}

private struct AutoQuitPaletteRow: View {
    @Environment(\.metrics) private var metrics
    let item: AutoQuitPaletteItem
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            Group {
                if let url = item.appURL {
                    EntryIconView(source: .file(stamp: FileIconStamp.value(for: url)), fileURL: url)
                } else {
                    EntryIconView(source: .symbol(item.symbol))
                }
            }
            .frame(width: metrics.size.resultRowIcon, height: metrics.size.resultRowIcon)
            VStack(alignment: .leading, spacing: metrics.spacing.xxs) {
                Text(item.title)
                    .font(metrics.typography.rowTitle)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: metrics.spacing.md)
            Text(item.trailing)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textSecondary)
            if item.isCurrent {
                SymbolImage(name: "checkmark", size: metrics.size.menuIcon)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(RoundedRectangle(cornerRadius: metrics.radius.row).fill(fill))
        .armedHover($hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue("\(item.subtitle), \(item.trailing)")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : [.isButton])
    }
}
