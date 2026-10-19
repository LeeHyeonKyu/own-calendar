import Foundation

struct WidgetAPIClient {
    static let serverBaseURL = "https://own-calendar.tailb2886a.ts.net/api"

    static func fetchTodayData(widgetKey: String) async -> TodayResponse? {
        guard !widgetKey.isEmpty,
              let url = URL(string: "\(serverBaseURL)/widget/today?key=\(widgetKey)") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(TodayResponse.self, from: data)
        } catch {
            return nil
        }
    }

    static func fetchMonthlyData(widgetKey: String, year: Int, month: Int) async -> MonthlyAPIResponse? {
        guard !widgetKey.isEmpty,
              let url = URL(string: "\(serverBaseURL)/widget/monthly?key=\(widgetKey)&year=\(year)&month=\(month)") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(MonthlyAPIResponse.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Today Response Models

struct TodayResponse: Codable {
    let events: [WidgetEvent]
    let tasks: [WidgetTask]
    let taskDone: Int
    let taskTotal: Int
}

struct WidgetEvent: Codable {
    let title: String
    let time: String
    let category: String
}

struct WidgetTask: Codable {
    let title: String
    let status: String
    let priority: String
    let time: String
    let dueDate: String
    let eventTitle: String
    let isOverdue: Bool
}

// MARK: - Monthly Response Models

struct MonthlyAPIResponse: Codable {
    let year: Int
    let month: Int
    let events: [String: [MonthlyAPIEvent]]
    let taskDays: [String: Bool]
    let tasks: [String: [MonthlyAPITask]]?
    let holidays: [String: String]?
}

struct MonthlyAPIEvent: Codable {
    let id: String
    let title: String
    let time: String
    let endTime: String?
    let category: String
    let isAllDay: Bool
}

struct MonthlyAPITask: Codable {
    let id: String
    let title: String
    let status: String
    let priority: String
    let time: String
    let isOverdue: Bool
}
