import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Models

struct MonthlyEntry: TimelineEntry {
    let date: Date
    let isLoggedIn: Bool
    let year: Int
    let month: Int
    let events: [Int: [MonthlyEvent]]  // day -> events
    let taskDays: Set<Int>             // days that have tasks (orange dots)
    let selectedDay: Int
    let eventPage: Int
    let showFamilyEvents: Bool
    let filterIndex: Int  // 0=all, 1+ = configured category presets
    let filterPresets: [String]  // configured category codes, e.g. ["WORK", "PERSONAL", "FAMILY", "HEALTH"]
}

struct MonthlyEvent: Codable, Identifiable {
    let id: String
    let title: String
    let time: String
    let endTime: String?
    let category: String
    let isFamily: Bool
    var displayId: String { "\(id)_\(time)" }
}

// MARK: - Calendar Grid Data

struct CalendarGridData {
    let year: Int
    let month: Int
    let daysInMonth: Int
    let firstWeekday: Int       // 0=Sunday, 1=Monday ... 6=Saturday
    let previousMonthDays: Int  // days in previous month

    var rowCount: Int {
        (firstWeekday + daysInMonth + 6) / 7
    }

    var totalCells: Int {
        rowCount * 7
    }

    static func calculate(year: Int, month: Int) -> CalendarGridData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1  // Sunday

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components) else {
            return CalendarGridData(year: year, month: month,
                                    daysInMonth: 30, firstWeekday: 0,
                                    previousMonthDays: 31)
        }

        // weekday: 1=Sunday ... 7=Saturday
        let weekday = calendar.component(.weekday, from: firstDay)
        let firstWeekdayIndex = weekday - 1  // 0-indexed

        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let daysInMonth = range.count

        // Previous month day count
        let prevMonth = month == 1 ? 12 : month - 1
        let prevYear  = month == 1 ? year - 1 : year
        var prevComponents = DateComponents()
        prevComponents.year = prevYear
        prevComponents.month = prevMonth
        prevComponents.day = 1
        let prevFirstDay = calendar.date(from: prevComponents)!
        let prevRange = calendar.range(of: .day, in: .month, for: prevFirstDay)!

        return CalendarGridData(
            year: year,
            month: month,
            daysInMonth: daysInMonth,
            firstWeekday: firstWeekdayIndex,
            previousMonthDays: prevRange.count
        )
    }
}

// MARK: - Color Constants

enum MonthlyColors {
    // Accent
    static let accent = Color(red: 52/255, green: 193/255, blue: 149/255)  // #34C195

    // Weekday text colors
    static func sunday(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 1.0, green: 107/255, blue: 107/255)       // #FF6B6B
            : Color(red: 232/255, green: 93/255, blue: 93/255)     // #E85D5D
    }

    static func saturday(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 110/255, green: 168/255, blue: 254/255)   // #6EA8FE
            : Color(red: 91/255, green: 141/255, blue: 239/255)    // #5B8DEF
    }

    // Category dot / bar colors
    static func categoryColor(_ category: String) -> Color {
        switch category {
        case "WORK":     return Color(red: 91/255, green: 141/255, blue: 239/255)   // #5B8DEF
        case "PERSONAL": return Color(red: 52/255, green: 193/255, blue: 149/255)   // #34C195
        case "FAMILY":   return Color(red: 232/255, green: 93/255, blue: 93/255)    // #E85D5D
        case "HEALTH":   return Color(red: 240/255, green: 164/255, blue: 50/255)   // #F0A432
        case "SOCIAL":   return Color(red: 97/255, green: 53/255, blue: 177/255)    // #6135B1
        case "FINANCE":  return Color(red: 26/255, green: 189/255, blue: 156/255)   // #1ABD9C
        default:         return Color(red: 142/255, green: 142/255, blue: 147/255)  // #8E8E93
        }
    }

    // Filter UI
    static let filterLabels     = ["전체", "업무", "개인", "건강", "가족"]
    static let filterCategories = ["", "WORK", "PERSONAL", "HEALTH", "FAMILY"]
}

// MARK: - Provider

struct MonthlyWidgetProvider: AppIntentTimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.owncalendar.ownCalendar")

    func placeholder(in context: Context) -> MonthlyEntry {
        let now = Date()
        let cal = Calendar.current
        let defaultPresets = ["WORK", "PERSONAL", "FAMILY", "HEALTH"]
        return MonthlyEntry(
            date: now, isLoggedIn: true,
            year: cal.component(.year, from: now),
            month: cal.component(.month, from: now),
            events: [:], taskDays: [],
            selectedDay: cal.component(.day, from: now),
            eventPage: 0, showFamilyEvents: true, filterIndex: 0,
            filterPresets: defaultPresets
        )
    }

    func snapshot(for configuration: MonthlyWidgetConfigIntent, in context: Context) async -> MonthlyEntry {
        getEntry(configuration: configuration)
    }

    func timeline(for configuration: MonthlyWidgetConfigIntent, in context: Context) async -> Timeline<MonthlyEntry> {
        let entry = getEntry(configuration: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    // MARK: Build entry from UserDefaults

    private func getEntry(configuration: MonthlyWidgetConfigIntent) -> MonthlyEntry {
        // Save configured presets to UserDefaults so CycleFilterIntent can read them
        let presets = configuration.filterCategories.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(presets),
           let json = String(data: data, encoding: .utf8) {
            userDefaults?.set(json, forKey: "monthlyFilterPresets")
        }
        let now = Date()
        let cal = Calendar.current
        let isLoggedIn = userDefaults?.bool(forKey: "isLoggedIn") ?? false

        guard isLoggedIn else {
            return MonthlyEntry(
                date: now, isLoggedIn: false,
                year: cal.component(.year, from: now),
                month: cal.component(.month, from: now),
                events: [:], taskDays: [],
                selectedDay: cal.component(.day, from: now),
                eventPage: 0, showFamilyEvents: true, filterIndex: 0,
                filterPresets: presets
            )
        }

        // Parse monthlyData JSON
        var year  = cal.component(.year, from: now)
        var month = cal.component(.month, from: now)
        var events: [Int: [MonthlyEvent]] = [:]
        var taskDays: Set<Int> = []

        if let jsonStr = userDefaults?.string(forKey: "monthlyData"),
           let data = jsonStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            year  = json["year"]  as? Int ?? year
            month = json["month"] as? Int ?? month

            if let eventsDict = json["events"] as? [String: Any] {
                for (dayStr, value) in eventsDict {
                    guard let day = Int(dayStr),
                          let arr = value as? [[String: Any]] else { continue }
                    var dayEvents: [MonthlyEvent] = []
                    for obj in arr {
                        guard let id       = obj["id"]       as? String,
                              let title    = obj["title"]    as? String,
                              let time     = obj["time"]     as? String,
                              let category = obj["category"] as? String else { continue }
                        dayEvents.append(MonthlyEvent(
                            id: id, title: title, time: time,
                            endTime: obj["endTime"] as? String,
                            category: category,
                            isFamily: obj["isFamily"] as? Bool ?? false
                        ))
                    }
                    events[day] = dayEvents
                }
            }

            // Parse task days
            if let taskDaysDict = json["taskDays"] as? [String: Any] {
                for (dayStr, _) in taskDaysDict {
                    if let day = Int(dayStr) {
                        taskDays.insert(day)
                    }
                }
            }
        }

        // Selected day — default to today (if current month) or 1
        let todayDay   = cal.component(.day, from: now)
        let todayMonth = cal.component(.month, from: now)
        let todayYear  = cal.component(.year, from: now)
        let isCurrentMonth = (year == todayYear && month == todayMonth)

        var selectedDay = userDefaults?.integer(forKey: "selectedDay") ?? 0
        if selectedDay <= 0 {
            selectedDay = isCurrentMonth ? todayDay : 1
        }
        // Clamp to valid range
        let gridData = CalendarGridData.calculate(year: year, month: month)
        selectedDay = min(selectedDay, gridData.daysInMonth)

        let eventPage = userDefaults?.integer(forKey: "eventPage") ?? 0

        // showFamilyEvents defaults to true (UserDefaults.bool returns false when key absent)
        let showFamilyEvents: Bool
        if userDefaults?.object(forKey: "showFamilyEvents") != nil {
            showFamilyEvents = userDefaults!.bool(forKey: "showFamilyEvents")
        } else {
            showFamilyEvents = true
        }

        let filterIndex = userDefaults?.integer(forKey: "monthlyFilterIndex") ?? 0

        return MonthlyEntry(
            date: now, isLoggedIn: true,
            year: year, month: month, events: events, taskDays: taskDays,
            selectedDay: selectedDay, eventPage: eventPage,
            showFamilyEvents: showFamilyEvents,
            filterIndex: min(filterIndex, presets.count),
            filterPresets: presets
        )
    }
}

// MARK: - Helper Functions

/// Filter events for a given day, respecting family toggle and category filter.
private func filteredEventsForDay(
    allEvents: [Int: [MonthlyEvent]],
    day: Int,
    showFamily: Bool,
    filterIndex: Int,
    filterPresets: [String]
) -> [MonthlyEvent] {
    guard var dayEvents = allEvents[day] else { return [] }

    if !showFamily {
        dayEvents = dayEvents.filter { !$0.isFamily }
    }
    // filterIndex 0 = "전체" (all), 1+ = configured presets
    if filterIndex > 0 && filterIndex <= filterPresets.count {
        let cat = filterPresets[filterIndex - 1]
        dayEvents = dayEvents.filter { $0.category == cat }
    }
    return dayEvents
}

/// Unique category strings for dot display (max 3).
private func categoriesForDay(
    allEvents: [Int: [MonthlyEvent]],
    day: Int,
    showFamily: Bool,
    filterIndex: Int,
    filterPresets: [String]
) -> [String] {
    let events = filteredEventsForDay(
        allEvents: allEvents, day: day,
        showFamily: showFamily, filterIndex: filterIndex,
        filterPresets: filterPresets
    )
    var seen = Set<String>()
    var result: [String] = []
    for e in events {
        if !seen.contains(e.category) {
            seen.insert(e.category)
            result.append(e.category)
            if result.count >= 3 { break }
        }
    }
    return result
}

/// Format a date as a Korean string.
private func koreanDateLabel(year: Int, month: Int, day: Int, format: String) -> String {
    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = day
    guard let date = Calendar.current.date(from: comps) else { return "" }
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "ko_KR")
    fmt.dateFormat = format
    return fmt.string(from: date)
}

/// Korean label for a category code.
private func categoryLabel(_ category: String) -> String {
    switch category {
    case "WORK":     return "업무"
    case "PERSONAL": return "개인"
    case "FAMILY":   return "가족"
    case "HEALTH":   return "건강"
    case "SOCIAL":   return "소셜"
    case "FINANCE":  return "금융"
    default:         return "기타"
    }
}

// MARK: - Login Required View

private struct MonthlyLoginRequiredView: View {
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("로그인이 필요합니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("앱을 열어 로그인해 주세요")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Day Cell View

private struct DayCellView: View {
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let column: Int           // 0=Sunday ... 6=Saturday
    let categories: [String]  // for event dots
    let hasTask: Bool         // show orange task dot
    let colorScheme: ColorScheme
    let dayFontSize: CGFloat
    let dotSize: CGFloat

    private var circleSize: CGFloat { dayFontSize < 12 ? 15 : 20 }

    // Task dot color (orange)
    private static let taskColor = Color(red: 240/255, green: 160/255, blue: 80/255) // #F0A050

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                if isToday && isCurrentMonth {
                    Circle()
                        .fill(MonthlyColors.accent)
                        .frame(width: circleSize, height: circleSize)
                }
                if isSelected && !isToday && isCurrentMonth {
                    Circle()
                        .fill(MonthlyColors.accent.opacity(0.10))
                        .frame(width: circleSize, height: circleSize)
                }
                Text("\(dayNumber)")
                    .font(.system(size: dayFontSize))
                    .fontWeight(isToday && isCurrentMonth ? .bold : .regular)
                    .foregroundColor(textColor)
            }
            .frame(height: circleSize)

            if isCurrentMonth && (!categories.isEmpty || hasTask) {
                HStack(spacing: 1.5) {
                    // Event category dots (max 2 to leave room for task dot)
                    ForEach(categories.prefix(hasTask ? 2 : 3), id: \.self) { cat in
                        Circle()
                            .fill(MonthlyColors.categoryColor(cat))
                            .frame(width: dotSize, height: dotSize)
                    }
                    // Task dot (orange)
                    if hasTask {
                        Circle()
                            .fill(Self.taskColor)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(height: dotSize)
            } else {
                Spacer().frame(height: dotSize)
            }
        }
    }

    private var textColor: Color {
        if !isCurrentMonth {
            return Color.secondary.opacity(0.3)
        }
        if isToday { return .white }
        switch column {
        case 0:  return MonthlyColors.sunday(colorScheme)
        case 6:  return MonthlyColors.saturday(colorScheme)
        default: return .primary
        }
    }
}

// MARK: - Calendar Grid View

private struct CalendarGridView: View {
    let entry: MonthlyEntry
    let colorScheme: ColorScheme
    let weekdayFontSize: CGFloat
    let dayFontSize: CGFloat
    let dotSize: CGFloat
    let gridSpacing: CGFloat
    let showHeader: Bool
    let headerFontSize: CGFloat
    let isInteractive: Bool

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    private var gridData: CalendarGridData {
        CalendarGridData.calculate(year: entry.year, month: entry.month)
    }

    private var todayDay: Int   { Calendar.current.component(.day,   from: Date()) }
    private var todayMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var todayYear: Int  { Calendar.current.component(.year,  from: Date()) }
    private var isCurrentMonth: Bool { entry.year == todayYear && entry.month == todayMonth }

    var body: some View {
        let data = gridData
        // Tighten spacing when 6 rows to prevent overflow in small widgets
        let rowSpacing: CGFloat = data.rowCount > 5 ? max(gridSpacing - 1, 0) : gridSpacing

        VStack(spacing: gridSpacing) {
            if showHeader {
                HStack {
                    Text("\(entry.month)월 \(String(entry.year))")
                        .font(.system(size: headerFontSize, weight: .bold))
                    Spacer()
                }
            }

            // Weekday header row
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { col in
                    Text(weekdays[col])
                        .font(.system(size: weekdayFontSize))
                        .foregroundColor(weekdayColor(col))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid — explicit rows for predictable layout
            VStack(spacing: rowSpacing) {
                ForEach(0..<data.rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let index = row * 7 + col
                            let info  = dayInfo(index: index, data: data)
                            dayCellWrapped(info: info, col: col)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func weekdayColor(_ column: Int) -> Color {
        switch column {
        case 0:  return MonthlyColors.sunday(colorScheme)
        case 6:  return MonthlyColors.saturday(colorScheme)
        default: return .secondary
        }
    }

    private struct DayInfo {
        let dayNumber: Int
        let isCurrentMonth: Bool
        let isToday: Bool
        let isSelected: Bool
        let categories: [String]
        let hasTask: Bool
    }

    private func dayInfo(index: Int, data: CalendarGridData) -> DayInfo {
        if index < data.firstWeekday {
            let day = data.previousMonthDays - data.firstWeekday + index + 1
            return DayInfo(dayNumber: day, isCurrentMonth: false,
                           isToday: false, isSelected: false, categories: [], hasTask: false)
        }
        if index >= data.firstWeekday + data.daysInMonth {
            let day = index - data.firstWeekday - data.daysInMonth + 1
            return DayInfo(dayNumber: day, isCurrentMonth: false,
                           isToday: false, isSelected: false, categories: [], hasTask: false)
        }
        let day = index - data.firstWeekday + 1
        let cats = categoriesForDay(
            allEvents: entry.events, day: day,
            showFamily: entry.showFamilyEvents, filterIndex: entry.filterIndex,
            filterPresets: entry.filterPresets
        )
        return DayInfo(
            dayNumber: day,
            isCurrentMonth: true,
            isToday: isCurrentMonth && day == todayDay,
            isSelected: day == entry.selectedDay,
            categories: cats,
            hasTask: entry.taskDays.contains(day)
        )
    }

    @ViewBuilder
    private func dayCellContent(info: DayInfo, col: Int) -> some View {
        DayCellView(
            dayNumber: info.dayNumber,
            isCurrentMonth: info.isCurrentMonth,
            isToday: info.isToday,
            isSelected: info.isSelected,
            column: col,
            categories: info.categories,
            hasTask: info.hasTask,
            colorScheme: colorScheme,
            dayFontSize: dayFontSize,
            dotSize: dotSize
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dayCellWrapped(info: DayInfo, col: Int) -> some View {
        if isInteractive && info.isCurrentMonth {
            if #available(iOS 17.0, *) {
                Button(intent: SelectDayIntent(day: info.dayNumber)) {
                    dayCellContent(info: info, col: col)
                }
                .buttonStyle(.plain)
            } else {
                dayCellContent(info: info, col: col)
            }
        } else {
            dayCellContent(info: info, col: col)
        }
    }
}

// MARK: - Event Row View

private struct EventRowView: View {
    let event: MonthlyEvent
    let showCategoryTag: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 6) {
            // Category color bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(MonthlyColors.categoryColor(event.category))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12))
                    .lineLimit(1)

                HStack(spacing: 2) {
                    Text(event.time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let endTime = event.endTime {
                        Text("- \(endTime)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 2)

            if showCategoryTag {
                Text(categoryLabel(event.category))
                    .font(.system(size: 9))
                    .foregroundColor(MonthlyColors.categoryColor(event.category))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(MonthlyColors.categoryColor(event.category).opacity(0.12))
                    )
            }
        }
    }
}

// MARK: - Events List View

private struct EventsListView: View {
    let entry: MonthlyEntry
    let colorScheme: ColorScheme
    let showCategoryTags: Bool
    let dateFormat: String      // "M/d (E)" for medium, "M월 d일 EEEE" for large
    let showAddButton: Bool

    private var allFiltered: [MonthlyEvent] {
        filteredEventsForDay(
            allEvents: entry.events, day: entry.selectedDay,
            showFamily: entry.showFamilyEvents, filterIndex: entry.filterIndex,
            filterPresets: entry.filterPresets
        )
    }

    private var pagedEvents: [MonthlyEvent] {
        let list = allFiltered
        guard !list.isEmpty else { return [] }
        let start = entry.eventPage * 3
        guard start < list.count else {
            // Page out of range — fall back to first page
            return Array(list.prefix(3))
        }
        return Array(list[start..<min(start + 3, list.count)])
    }

    private var needsPager: Bool { allFiltered.count > 3 }

    private var canPageDown: Bool { allFiltered.count > (entry.eventPage + 1) * 3 }

    private var dateString: String {
        String(format: "%04d-%02d-%02d", entry.year, entry.month, entry.selectedDay)
    }

    private var dateLabel: String {
        koreanDateLabel(year: entry.year, month: entry.month,
                        day: entry.selectedDay, format: dateFormat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date header + add button
            HStack {
                Text(dateLabel)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if showAddButton {
                    addButton
                }
            }

            if allFiltered.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("일정이 없습니다")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                HStack(alignment: .center, spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(pagedEvents, id: \.displayId) { event in
                            if let encoded = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                               let url = URL(string: "owncalendar://event/\(encoded)") {
                                Link(destination: url) {
                                    EventRowView(
                                        event: event,
                                        showCategoryTag: showCategoryTags,
                                        colorScheme: colorScheme
                                    )
                                }
                            } else {
                                EventRowView(
                                    event: event,
                                    showCategoryTag: showCategoryTags,
                                    colorScheme: colorScheme
                                )
                            }
                        }
                    }

                    if needsPager {
                        VStack(spacing: 4) {
                            Spacer()
                            if #available(iOS 17.0, *) {
                                Button(intent: PageEventsIntent(direction: -1)) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(entry.eventPage > 0 ? .primary : .secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.eventPage <= 0)

                                Button(intent: PageEventsIntent(direction: 1)) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(canPageDown ? .primary : .secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                                .disabled(!canPageDown)
                            } else {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(width: 16)
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Link(destination: URL(string: "owncalendar://add?date=\(dateString)")!) {
            ZStack {
                Circle()
                    .fill(MonthlyColors.accent)
                    .frame(width: 22, height: 22)
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Small Monthly View

private struct SmallMonthlyView: View {
    let entry: MonthlyEntry
    let colorScheme: ColorScheme

    var body: some View {
        CalendarGridView(
            entry: entry, colorScheme: colorScheme,
            weekdayFontSize: 8, dayFontSize: 10, dotSize: 3,
            gridSpacing: 2, showHeader: true, headerFontSize: 11,
            isInteractive: false
        )
        .widgetURL(URL(string: "owncalendar://monthly")!)
    }
}

// MARK: - Medium Monthly View

private struct MediumMonthlyView: View {
    let entry: MonthlyEntry
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Left — calendar grid
            CalendarGridView(
                entry: entry, colorScheme: colorScheme,
                weekdayFontSize: 8, dayFontSize: 10, dotSize: 3,
                gridSpacing: 2, showHeader: true, headerFontSize: 11,
                isInteractive: true
            )
            .frame(maxWidth: .infinity)

            // Vertical divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right — events list
            EventsListView(
                entry: entry, colorScheme: colorScheme,
                showCategoryTags: false,
                dateFormat: "M/d (E)",
                showAddButton: true
            )
            .frame(maxWidth: .infinity)
            .padding(.leading, 8)
        }
    }
}

// MARK: - Large Monthly View

private struct LargeMonthlyView: View {
    let entry: MonthlyEntry
    let colorScheme: ColorScheme

    private var filterLabels: [String] {
        ["전체"] + entry.filterPresets.map { categoryLabel($0) }
    }

    private var filterCategoryKeys: [String] {
        [""] + entry.filterPresets
    }

    private var safeFilterIndex: Int {
        min(entry.filterIndex, entry.filterPresets.count)
    }

    private var addDateString: String {
        String(format: "%04d-%02d-%02d", entry.year, entry.month, entry.selectedDay)
    }

    private var familyToggleContent: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2")
                .font(.system(size: 10))
            Text("가족")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(
            entry.showFamilyEvents ? MonthlyColors.accent : .secondary
        )
        .background(
            Capsule().fill(
                entry.showFamilyEvents
                    ? MonthlyColors.accent.opacity(0.15)
                    : Color.secondary.opacity(0.10)
            )
        )
    }

    private var filterButtonContent: some View {
        Text(filterLabels[safeFilterIndex])
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(
                safeFilterIndex > 0
                    ? MonthlyColors.categoryColor(filterCategoryKeys[safeFilterIndex])
                    : .secondary
            )
            .background(
                Capsule().fill(
                    safeFilterIndex > 0
                        ? MonthlyColors.categoryColor(filterCategoryKeys[safeFilterIndex]).opacity(0.15)
                        : Color.secondary.opacity(0.10)
                )
            )
    }

    var body: some View {
        VStack(spacing: 4) {
            // Header row
            HStack(spacing: 6) {
                Text("\(entry.month)월 \(String(entry.year))")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                // Family toggle pill
                if #available(iOS 17.0, *) {
                    Button(intent: ToggleFamilyIntent()) {
                        familyToggleContent
                    }
                    .buttonStyle(.plain)
                } else {
                    familyToggleContent
                }

                // Filter button
                if #available(iOS 17.0, *) {
                    Button(intent: CycleFilterIntent()) {
                        filterButtonContent
                    }
                    .buttonStyle(.plain)
                } else {
                    filterButtonContent
                }

                // Add button
                Link(destination: URL(string: "owncalendar://add?date=\(addDateString)")!) {
                    ZStack {
                        Circle()
                            .fill(MonthlyColors.accent)
                            .frame(width: 24, height: 24)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Calendar grid (header handled above)
            CalendarGridView(
                entry: entry, colorScheme: colorScheme,
                weekdayFontSize: 10, dayFontSize: 12, dotSize: 4,
                gridSpacing: 3, showHeader: false, headerFontSize: 0,
                isInteractive: true
            )

            // Horizontal divider
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 2)

            // Events list (date label format: "9월 1일 화요일")
            EventsListView(
                entry: entry, colorScheme: colorScheme,
                showCategoryTags: true,
                dateFormat: "M월 d일 EEEE",
                showAddButton: false
            )
        }
    }
}

// MARK: - Main Widget View

struct MonthlyWidgetView: View {
    var entry: MonthlyEntry

    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if !entry.isLoggedIn {
                MonthlyLoginRequiredView()
            } else {
                switch family {
                case .systemSmall:
                    SmallMonthlyView(entry: entry, colorScheme: colorScheme)
                case .systemMedium:
                    MediumMonthlyView(entry: entry, colorScheme: colorScheme)
                case .systemLarge:
                    LargeMonthlyView(entry: entry, colorScheme: colorScheme)
                default:
                    MediumMonthlyView(entry: entry, colorScheme: colorScheme)
                }
            }
        }
    }
}

// MARK: - Widget Definition

struct OwnCalendarMonthlyWidget: Widget {
    let kind: String = "OwnCalendarMonthlyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MonthlyWidgetConfigIntent.self, provider: MonthlyWidgetProvider()) { entry in
            MonthlyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("월별 캘린더")
        .description("이번 달 일정을 한눈에 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
