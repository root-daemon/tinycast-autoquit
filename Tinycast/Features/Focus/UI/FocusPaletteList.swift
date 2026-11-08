import SwiftUI

struct FocusPaletteItem: Identifiable {
    enum Action {
        case submit
        case minutes(Int?)
        case customMinutes
        case mode(FocusMode)
        case apps
        case category(String)
        case app(String)
        case takeBreak(Int?)
    }

    let id: String
    let title: String
    var subtitle = ""
    var trailing = ""
    let symbol: String
    var appURL: URL?
    var section: String?
    var isCurrent = false
    let action: Action
}

struct FocusPaletteList: View {
    @Environment(\.metrics) private var metrics
    let rows: [FocusPaletteItem]
    let selectedID: String?
    let scroll: ScrollIntent
    let onActivate: (FocusPaletteItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        if let section = row.section {
                            SectionHeader(title: section)
                        }
                        FocusPaletteRow(item: row, selected: row.id == selectedID)
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

private struct FocusPaletteRow: View {
    @Environment(\.metrics) private var metrics
    let item: FocusPaletteItem
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
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(metrics.typography.rowTrailing)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: metrics.spacing.md)
            Text(item.trailing)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
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
        .accessibilityAddTraits(
            item.isCurrent || selected ? [.isSelected, .isButton] : [.isButton])
    }
}
