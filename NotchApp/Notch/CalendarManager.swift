import Foundation
import EventKit
import Combine
import SwiftUI

enum CalendarSource: String {
    case local, notion, both
}

struct UnifiedEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let color: Color
    let source: CalendarSource
    let location: String?
    let calendarName: String?
    let isAllDay: Bool
}

class CalendarManager: ObservableObject {
    @Published var permissionStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderPermissionStatus: EKAuthorizationStatus = .notDetermined
    @Published var selectedDate: Date = Date()
    @Published var events: [UnifiedEvent] = []
    @Published var isLoading: Bool = false
    
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkPermission()
        var hasAccess = permissionStatus.rawValue == 3
        if #available(macOS 14.0, *) {
            if permissionStatus == .fullAccess { hasAccess = true }
        }
        if hasAccess {
            refresh()
        }
    }
    
    func checkPermission() {
        permissionStatus = EKEventStore.authorizationStatus(for: .event)
        reminderPermissionStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    func requestAccess() {
        print("Requesting Access...")
        
        // Request Events first
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                print("Events granted: \(granted), error: \(String(describing: error))")
                DispatchQueue.main.async {
                    if !granted {
                        self?.permissionStatus = .denied
                    } else {
                        self?.permissionStatus = .fullAccess
                    }
                    self?.checkPermission()
                    
                    // Then request Reminders
                    self?.eventStore.requestFullAccessToReminders { rGranted, rError in
                        print("Reminders granted: \(rGranted), error: \(String(describing: rError))")
                        DispatchQueue.main.async {
                            if !rGranted {
                                self?.reminderPermissionStatus = .denied
                            } else {
                                self?.reminderPermissionStatus = .fullAccess
                            }
                            self?.checkPermission()
                            if granted || rGranted { self?.refresh() }
                        }
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.permissionStatus = granted ? EKAuthorizationStatus(rawValue: 3)! : .denied
                    self?.eventStore.requestAccess(to: .reminder) { rGranted, _ in
                        DispatchQueue.main.async {
                            self?.reminderPermissionStatus = rGranted ? EKAuthorizationStatus(rawValue: 3)! : .denied
                            self?.checkPermission()
                            if granted || rGranted { self?.refresh() }
                        }
                    }
                }
            }
        }
    }
    
    func refresh() {
        fetchEvents(for: selectedDate)
    }
    
    func fetchEvents(for date: Date) {
        self.selectedDate = date
        self.events = []
        
        let source = CalendarSource(rawValue: SettingsManager.shared.calendarSource) ?? .local
        
        if source == .local || source == .both {
            fetchLocalEvents(for: date)
        }
        
        if source == .notion || source == .both {
            fetchNotionEvents(for: date)
        }
    }
    
    private func fetchLocalEvents(for date: Date) {
        var isAuthorized = false
        if #available(macOS 14.0, *) {
            isAuthorized = (permissionStatus == .fullAccess || permissionStatus.rawValue == 3)
        } else {
            isAuthorized = (permissionStatus.rawValue == 3)
        }
        
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        let unified = ekEvents.map { event in
            UnifiedEvent(
                id: event.eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                color: Color(nsColor: event.calendar.color),
                source: .local,
                location: event.location,
                calendarName: event.calendar.title,
                isAllDay: event.isAllDay
            )
        }
        
        DispatchQueue.main.async {
            self.events.append(contentsOf: unified)
            self.events.sort { $0.startDate < $1.startDate }
        }
        
        fetchLocalReminders(for: date)
    }
    
    private func fetchLocalReminders(for date: Date) {
        let isAuthorized: Bool
        if #available(macOS 14.0, *) {
            isAuthorized = (reminderPermissionStatus == .fullAccess || reminderPermissionStatus.rawValue == 3)
        } else {
            isAuthorized = (reminderPermissionStatus.rawValue == 3)
        }
        
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: startOfDay, ending: endOfDay, calendars: nil)
        
        eventStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
            guard let ekReminders = ekReminders else { return }
            
            let unified = ekReminders.map { reminder in
                UnifiedEvent(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title,
                    startDate: reminder.dueDateComponents?.date ?? startOfDay,
                    endDate: (reminder.dueDateComponents?.date ?? startOfDay).addingTimeInterval(1800),
                    color: Color(nsColor: reminder.calendar.color),
                    source: .local,
                    location: "Reminder",
                    calendarName: reminder.calendar.title,
                    isAllDay: false
                )
            }
            
            DispatchQueue.main.async {
                self?.events.append(contentsOf: unified)
                self?.events.sort { $0.startDate < $1.startDate }
            }
        }
    }
    
    private func fetchNotionEvents(for date: Date) {
        let token = SettingsManager.shared.notionToken
        let dbId = SettingsManager.shared.notionDatabaseID
        let datePropName = SettingsManager.shared.notionDateProperty
        let titlePropName = SettingsManager.shared.notionTitleProperty
        
        guard !token.isEmpty && !dbId.isEmpty else { return }
        
        self.isLoading = true
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Format date for Notion query (YYYY-MM-DD)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: startOfDay)
        
        let url = URL(string: "https://api.notion.com/v1/databases/\(dbId)/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Query filter: find entries where the Date property equals our selected date
        let body: [String: Any] = [
            "filter": [
                "property": datePropName,
                "date": [
                    "equals": dateString
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async { self?.isLoading = false }
            
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    
                    let notionEvents = results.compactMap { result -> UnifiedEvent? in
                        let properties = result["properties"] as? [String: Any]
                        
                        // Parse Title
                        let nameProp = properties?[titlePropName] as? [String: Any]
                        let titleArray = nameProp?["title"] as? [[String: Any]]
                        let title = titleArray?.first?["plain_text"] as? String ?? "Untitled"
                        
                        // Parse Date
                        let dateProp = properties?[datePropName] as? [String: Any]
                        let dateData = dateProp?["date"] as? [String: Any]
                        let startStr = dateData?["start"] as? String ?? ""
                        
                        // Notion dates can be ISO8601
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                        
                        let startDate = isoFormatter.date(from: startStr) ?? 
                                       DateFormatter.yyyyMMdd.date(from: startStr) ?? date
                        
                        return UnifiedEvent(
                            id: result["id"] as? String ?? UUID().uuidString,
                            title: title,
                            startDate: startDate,
                            endDate: startDate.addingTimeInterval(3600), // Default 1h
                            color: .gray, // Notion source color
                            source: .notion,
                            location: nil,
                            calendarName: "Notion",
                            isAllDay: false
                        )
                    }
                    
                    DispatchQueue.main.async {
                        self?.events.append(contentsOf: notionEvents)
                        self?.events.sort { $0.startDate < $1.startDate }
                    }
                }
            } catch {
                print("Notion Parse Error: \(error)")
            }
        }.resume()
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
