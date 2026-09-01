import AppIntents
import WidgetKit

// All intents use the same UserDefaults suite
private let widgetDefaults = UserDefaults(suiteName: "group.com.owncalendar.ownCalendar")

// MARK: - Widget Category Enum

enum WidgetCategory: String, AppEnum {
    case work = "WORK"
    case personal = "PERSONAL"
    case family = "FAMILY"
    case health = "HEALTH"
    case social = "SOCIAL"
    case finance = "FINANCE"
    case other = "OTHER"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "카테고리"

    static var caseDisplayRepresentations: [WidgetCategory: DisplayRepresentation] = [
        .work: "업무",
        .personal: "개인",
        .family: "가족",
        .health: "건강",
        .social: "소셜",
        .finance: "금융",
        .other: "기타",
    ]
}

// MARK: - Widget Configuration Intent

struct MonthlyWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "월별 캘린더 설정"
    static var description = IntentDescription("위젯에 표시할 카테고리 필터를 선택합니다.")

    @Parameter(title: "필터 카테고리", default: [.work, .personal, .family, .health])
    var filterCategories: [WidgetCategory]
}

// MARK: - Day Selection Intent

struct SelectDayIntent: AppIntent {
    static var title: LocalizedStringResource = "날짜 선택"

    @Parameter(title: "Day")
    var day: Int

    init() { self.day = 1 }
    init(day: Int) { self.day = day }

    func perform() async throws -> some IntentResult {
        widgetDefaults?.set(day, forKey: "selectedDay")
        widgetDefaults?.set(0, forKey: "eventPage") // reset page on date change
        WidgetCenter.shared.reloadTimelines(ofKind: "OwnCalendarMonthlyWidget")
        return .result()
    }
}

// MARK: - Event Paging Intent

struct PageEventsIntent: AppIntent {
    static var title: LocalizedStringResource = "일정 페이지"

    @Parameter(title: "Direction")
    var direction: Int  // 1 = next, -1 = previous

    init() { self.direction = 1 }
    init(direction: Int) { self.direction = direction }

    func perform() async throws -> some IntentResult {
        let current = widgetDefaults?.integer(forKey: "eventPage") ?? 0
        let newPage = max(0, current + direction)
        widgetDefaults?.set(newPage, forKey: "eventPage")
        WidgetCenter.shared.reloadTimelines(ofKind: "OwnCalendarMonthlyWidget")
        return .result()
    }
}

// MARK: - Family Toggle Intent

struct ToggleFamilyIntent: AppIntent {
    static var title: LocalizedStringResource = "가족 일정 토글"

    func perform() async throws -> some IntentResult {
        let current: Bool
        if widgetDefaults?.object(forKey: "showFamilyEvents") != nil {
            current = widgetDefaults!.bool(forKey: "showFamilyEvents")
        } else {
            current = true
        }
        widgetDefaults?.set(!current, forKey: "showFamilyEvents")
        widgetDefaults?.set(0, forKey: "eventPage") // reset page
        WidgetCenter.shared.reloadTimelines(ofKind: "OwnCalendarMonthlyWidget")
        return .result()
    }
}

// MARK: - Category Filter Cycle Intent

struct CycleFilterIntent: AppIntent {
    static var title: LocalizedStringResource = "카테고리 필터"

    func perform() async throws -> some IntentResult {
        let current = widgetDefaults?.integer(forKey: "monthlyFilterIndex") ?? 0

        // Read configured presets count (+ 1 for "전체")
        let presetCount: Int
        if let json = widgetDefaults?.string(forKey: "monthlyFilterPresets"),
           let data = json.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            presetCount = arr.count + 1  // +1 for "전체"
        } else {
            presetCount = 5  // default: 전체 + 4 categories
        }

        let next = (current + 1) % presetCount
        widgetDefaults?.set(next, forKey: "monthlyFilterIndex")
        widgetDefaults?.set(0, forKey: "eventPage") // reset page
        WidgetCenter.shared.reloadTimelines(ofKind: "OwnCalendarMonthlyWidget")
        return .result()
    }
}
