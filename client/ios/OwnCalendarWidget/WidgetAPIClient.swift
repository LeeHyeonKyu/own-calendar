import Foundation
import Security

struct WidgetAPIClient {
    static let serverBaseURL = "https://own-calendar.tailb2886a.ts.net/api"
    private static let keychainAccessGroup = "group.com.owncalendar.ownCalendar"
    private static let keychainService = "flutter_secure_storage_service"
    private static let userDefaults = UserDefaults(suiteName: "group.com.owncalendar.ownCalendar")

    // MARK: - Keychain

    static func fetchToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: "accessToken",
            kSecAttrAccessGroup: keychainAccessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    // MARK: - Today

    static func fetchTodayData() async -> TodayResponse? {
        guard let token = fetchToken(),
              let url = URL(string: "\(serverBaseURL)/widget/today") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(TodayResponse.self, from: data)
            cacheTodayToUserDefaults(decoded)
            return decoded
        } catch {
            return nil
        }
    }

    // MARK: - Monthly

    static func fetchMonthlyData(year: Int, month: Int) async -> MonthlyAPIResponse? {
        guard let token = fetchToken(),
              let url = URL(string: "\(serverBaseURL)/widget/monthly?year=\(year)&month=\(month)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(MonthlyAPIResponse.self, from: data)
            cacheMonthlyToUserDefaults(decoded, rawData: data)
            return decoded
        } catch {
            return nil
        }
    }

    // MARK: - Cache to UserDefaults

    private static func cacheTodayToUserDefaults(_ response: TodayResponse) {
        guard let ud = userDefaults else { return }
        if let eventsData = try? JSONEncoder().encode(response.events),
           let eventsStr = String(data: eventsData, encoding: .utf8) {
            ud.set(eventsStr, forKey: "todayEvents")
        }
        if let tasksData = try? JSONEncoder().encode(response.tasks),
           let tasksStr = String(data: tasksData, encoding: .utf8) {
            ud.set(tasksStr, forKey: "todayTasks")
        }
        ud.set(response.taskDone, forKey: "taskDone")
        ud.set(response.taskTotal, forKey: "taskTotal")
        ud.set(true, forKey: "isLoggedIn")
    }

    private static func cacheMonthlyToUserDefaults(_ response: MonthlyAPIResponse, rawData: Data) {
        guard let ud = userDefaults else { return }
        if let jsonStr = String(data: rawData, encoding: .utf8) {
            ud.set(jsonStr, forKey: "monthlyData")
        }
        ud.set(true, forKey: "isLoggedIn")
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
}

struct MonthlyAPIEvent: Codable {
    let id: String
    let title: String
    let time: String
    let endTime: String?
    let category: String
    let isAllDay: Bool
}
