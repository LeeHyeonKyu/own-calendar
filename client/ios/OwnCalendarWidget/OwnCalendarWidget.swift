import WidgetKit
import SwiftUI

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [CalendarEvent]
    let tasks: [CalendarTask]
    let taskDone: Int
    let taskTotal: Int
    let isLoggedIn: Bool
}

struct CalendarEvent: Codable, Identifiable {
    let title: String
    let time: String
    let category: String
    var id: String { "\(title)_\(time)" }
}

struct CalendarTask: Codable, Identifiable {
    let title: String
    let status: String
    let priority: String
    let time: String
    let dueDate: String
    let eventTitle: String
    let isOverdue: Bool
    var id: String { "\(title)_\(status)_\(time)" }
    var isDone: Bool { status == "DONE" }
}

struct OwnCalendarProvider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.owncalendar.ownCalendar")

    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(), events: [
            CalendarEvent(title: "일정 로딩 중...", time: "09:00", category: "PERSONAL")
        ], tasks: [], taskDone: 0, taskTotal: 0, isLoggedIn: true)
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
            return EventEntry(date: Date(), events: [], tasks: [], taskDone: 0, taskTotal: 0, isLoggedIn: false)
        }

        var events: [CalendarEvent] = []
        if let jsonStr = userDefaults?.string(forKey: "todayEvents"),
           let data = jsonStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CalendarEvent].self, from: data) {
            events = decoded
        }

        var tasks: [CalendarTask] = []
        if let jsonStr = userDefaults?.string(forKey: "todayTasks"),
           let data = jsonStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CalendarTask].self, from: data) {
            tasks = decoded
        }

        let taskDone = userDefaults?.integer(forKey: "taskDone") ?? 0
        let taskTotal = userDefaults?.integer(forKey: "taskTotal") ?? 0

        return EventEntry(date: Date(), events: events, tasks: tasks,
                          taskDone: taskDone, taskTotal: taskTotal, isLoggedIn: true)
    }
}

struct OwnCalendarWidgetView: View {
    var entry: EventEntry

    @Environment(\.widgetFamily) var family

    private static let taskColor = Color(red: 240/255, green: 160/255, blue: 80/255)
    private static let overdueColor = Color(red: 239/255, green: 107/255, blue: 107/255)
    private static let doneColor = Color(red: 74/255, green: 222/255, blue: 128/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("오늘")
                    .font(.headline)
                    .fontWeight(.bold)
                if entry.taskTotal > 0 {
                    Text("\(entry.taskDone)/\(entry.taskTotal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Self.doneColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Self.doneColor.opacity(0.15))
                        )
                }
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
            } else if entry.events.isEmpty && entry.tasks.isEmpty {
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
                // Events
                ForEach(entry.events.prefix(eventLimit)) { event in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor(event.category))
                            .frame(width: 7, height: 7)
                        Text(event.time)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .leading)
                        Text(event.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }
                if entry.events.count > eventLimit {
                    Text("+\(entry.events.count - eventLimit)건 더")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Tasks (undone only)
                let undoneTasks = entry.tasks.filter { !$0.isDone }
                if !undoneTasks.isEmpty {
                    if !entry.events.isEmpty {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                            .padding(.vertical, 1)
                    }
                    ForEach(undoneTasks.prefix(taskLimit)) { task in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(task.isOverdue ? Self.overdueColor : Self.taskColor, lineWidth: 1.5)
                                .frame(width: 11, height: 11)
                            if !task.time.isEmpty {
                                Text(task.time)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .leading)
                            }
                            Text(task.title)
                                .font(.system(size: 12))
                                .foregroundColor(task.isOverdue ? Self.overdueColor : .primary)
                                .lineLimit(1)
                        }
                    }
                    if undoneTasks.count > taskLimit {
                        Text("+\(undoneTasks.count - taskLimit)건 할 일 더")
                            .font(.system(size: 10))
                            .foregroundColor(Self.taskColor)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    var eventLimit: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge: return 5
        default: return 3
        }
    }

    var taskLimit: Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 2
        case .systemLarge: return 4
        default: return 2
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
