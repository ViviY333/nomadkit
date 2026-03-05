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
            Text("Packing List")
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 2)

            ForEach(entry.items, id: \.id) { item in
                Button(intent: TogglePackingItemIntent(itemID: item.id)) {
                    HStack(spacing: 8) {
                        Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(item.isSelected ? .green : .secondary)
                        Text(item.title)
                            .font(.system(size: 13))
                            .strikethrough(item.isSelected)
                            .foregroundStyle(item.isSelected ? .secondary : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct PackingListWidget: Widget {
    let kind = "PackingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PackingProvider()) { entry in
            PackingListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Packing List")
        .description("Check off your packing items")
        .supportedFamilies([.systemMedium])
    }
}
