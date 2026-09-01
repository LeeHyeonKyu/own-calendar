import WidgetKit
import SwiftUI

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [CalendarEvent]
    let isLoggedIn: Bool
}

struct CalendarEvent: Codable, Identifiable {
    let title: String
    let time: String
    let category: String
    var id: String { "\(title)_\(time)" }
}

struct OwnCalendarProvider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.owncalendar.ownCalendar")

    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(), events: [
            CalendarEvent(title: "일정 로딩 중...", time: "09:00", category: "PERSONAL")
        ], isLoggedIn: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        completion(getEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let entry = getEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getEntry() -> EventEntry {
        let isLoggedIn = userDefaults?.bool(forKey: "isLoggedIn") ?? false

        guard isLoggedIn else {
            return EventEntry(date: Date(), events: [], isLoggedIn: false)
        }

        guard let jsonStr = userDefaults?.string(forKey: "todayEvents"),
              let data = jsonStr.data(using: .utf8),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return EventEntry(date: Date(), events: [], isLoggedIn: true)
        }
        return EventEntry(date: Date(), events: events, isLoggedIn: true)
    }
}

struct OwnCalendarWidgetView: View {
    var entry: EventEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("오늘 일정")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            if !entry.isLoggedIn {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("로그인이 필요합니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("앱을 열어 로그인해 주세요")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if entry.events.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("일정이 없습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.events.prefix(eventLimit)) { event in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(categoryColor(event.category))
                            .frame(width: 8, height: 8)
                        Text(event.time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .leading)
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                if entry.events.count > eventLimit {
                    Text("+\(entry.events.count - eventLimit)건 더")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    var eventLimit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 8
        default: return 4
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }

    func categoryColor(_ category: String) -> Color {
        switch category {
        case "WORK": return Color(red: 0.29, green: 0.56, blue: 0.85)
        case "PERSONAL": return Color(red: 0.31, green: 0.78, blue: 0.47)
        case "FAMILY": return Color(red: 1.0, green: 0.42, blue: 0.42)
        case "HEALTH": return Color(red: 1.0, green: 0.7, blue: 0.28)
        case "SOCIAL": return Color(red: 0.61, green: 0.35, blue: 0.71)
        case "FINANCE": return Color(red: 0.1, green: 0.74, blue: 0.61)
        default: return Color(red: 0.58, green: 0.65, blue: 0.65)
        }
    }
}

struct OwnCalendarWidget: Widget {
    let kind: String = "OwnCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OwnCalendarProvider()) { entry in
            if #available(iOS 17.0, *) {
                OwnCalendarWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                OwnCalendarWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("오늘 일정")
        .description("오늘의 일정을 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
