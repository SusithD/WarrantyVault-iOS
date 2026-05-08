import WidgetKit
import SwiftUI


@main
struct WarrantyVaultWidgetBundle: WidgetBundle {
    var body: some Widget {
        WarrantyVaultWidget()
    }
}


struct WarrantyVaultWidget: Widget {
    let kind: String = "WarrantyVaultWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WarrantyVaultWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Expiry")
        .description("Shows the next warranty about to expire.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let snapshot = WidgetSnapshotStore.read() ?? .placeholder
        completion(Entry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read() ?? .empty
        let entry = Entry(date: Date(), snapshot: snapshot)

        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}


struct WarrantyVaultWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        switch family {
        case .systemMedium: MediumView(snapshot: entry.snapshot)
        default:            SmallView(snapshot: entry.snapshot)
        }
    }
}

private struct SmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: categorySymbol(snapshot.nextCategoryRaw))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(categoryTint(snapshot.nextCategoryRaw))
                Spacer()
                Text(snapshot.nextCategoryRaw.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(snapshot.nextProductName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
            Text(daysLabel(snapshot.nextDaysUntilExpiry))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .widgetURL(deepLink(for: snapshot))
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: categorySymbol(snapshot.nextCategoryRaw))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(categoryTint(snapshot.nextCategoryRaw))
                    Text(snapshot.nextCategoryRaw)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(snapshot.nextProductName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                Text(daysLabel(snapshot.nextDaysUntilExpiry))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(snapshot.totalActive) active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(deepLink(for: snapshot))
    }
}


private func categoryTint(_ raw: String) -> Color {
    switch raw {
    case "Electronics": return .blue
    case "Appliance":   return .purple
    case "Vehicle":     return .orange
    case "Furniture":   return .pink
    case "Jewelry":     return .yellow
    case "Tools":       return .green
    default:            return .gray
    }
}

private func categorySymbol(_ raw: String) -> String {
    switch raw {
    case "Electronics": return "tv.inset.filled"
    case "Appliance":   return "washer"
    case "Vehicle":     return "car.fill"
    case "Furniture":   return "sofa.fill"
    case "Jewelry":     return "sparkles"
    case "Tools":       return "wrench.and.screwdriver.fill"
    default:            return "shippingbox.fill"
    }
}

private func daysLabel(_ days: Int) -> String {
    switch days {
    case ..<0:       return "Expired"
    case 0:          return "Expires today"
    case 1:          return "Expires tomorrow"
    default:         return "\(days) days remaining"
    }
}

private func deepLink(for snapshot: WidgetSnapshot) -> URL? {
    guard let id = snapshot.nextWarrantyId else { return URL(string: "warrantyvault://home") }
    return URL(string: "warrantyvault://warranty/\(id.uuidString)")
}


#Preview(as: .systemSmall) {
    WarrantyVaultWidget()
} timeline: {
    Entry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    WarrantyVaultWidget()
} timeline: {
    Entry(date: .now, snapshot: .placeholder)
}
