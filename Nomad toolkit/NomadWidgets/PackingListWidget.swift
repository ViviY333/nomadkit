import WidgetKit
import SwiftUI
import AppIntents

struct TogglePackingItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Packing Item"

    @Parameter(title: "Item ID")
    var itemID: String

    init(itemID: String) {
        self.itemID = itemID
    }

    init() {}

    func perform() async throws -> some IntentResult {
        var selected = Set(SharedDefaults.store.array(forKey: "packingSelectedIDs") as? [String] ?? [])
        if selected.contains(itemID) {
            selected.remove(itemID)
        } else {
            selected.insert(itemID)
        }
        SharedDefaults.store.set(Array(selected), forKey: "packingSelectedIDs")
        return .result()
    }
}

struct PackingEntry: TimelineEntry {
    let date: Date
    let items: [(id: String, title: String, isSelected: Bool)]
}

struct PackingProvider: TimelineProvider {
    static let allItems: [(id: String, title: String)] = [
        ("packing_laptop", "Laptop"),
        ("packing_powerbank", "Power Bank"),
        ("packing_headphones", "Headphones"),
        ("packing_wallet", "Wallet"),
        ("packing_sim", "Sim Card"),
        ("packing_shoes", "Shoes")
    ]

    func placeholder(in context: Context) -> PackingEntry {
        PackingEntry(date: .now, items: Self.allItems.map { ($0.id, $0.title, false) })
    }

    func getSnapshot(in context: Context, completion: @escaping (PackingEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PackingEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }

    private func loadEntry() -> PackingEntry {
        let selected = Set(SharedDefaults.store.array(forKey: "packingSelectedIDs") as? [String] ?? [])
        let items = Self.allItems.map { ($0.id, $0.title, selected.contains($0.id)) }
        return PackingEntry(date: .now, items: items)
    }
}

struct PackingListWidgetView: View {
    let entry: PackingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 3x2 grid of item images matching the app layout
            VStack(spacing: 0) {
                // Row 1
                HStack(spacing: 0) {
                    ForEach(Array(entry.items.prefix(3)), id: \.id) { item in
                        packingItemView(item: item)
                    }
                }
                // Row 2
                HStack(spacing: 0) {
                    ForEach(Array(entry.items.suffix(3)), id: \.id) { item in
                        packingItemView(item: item)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func packingItemView(item: (id: String, title: String, isSelected: Bool)) -> some View {
        Button(intent: TogglePackingItemIntent(itemID: item.id)) {
            ZStack {
                Image(item.id)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 68)
                    .saturation(item.isSelected ? 1 : 0)
                    .opacity(item.isSelected ? 1 : 0.6)

                if item.isSelected {
                    Image("Vector")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct PackingListWidget: Widget {
    let kind = "PackingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PackingProvider()) { entry in
            PackingListWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Packing List")
        .description("Check off your packing items")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
