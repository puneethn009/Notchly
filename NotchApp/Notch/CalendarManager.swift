import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    @Published var permissionStatus: EKAuthorizationStatus = .notDetermined
    @Published var selectedDate: Date = Date()
    @Published var eventsForSelectedDate: [EKEvent] = []
    
    private let eventStore = EKEventStore()
    private var timer: AnyCancellable?
    
    init() {
        checkPermission()
        fetchEvents(for: selectedDate)
    }
    
    func checkPermission() {
        permissionStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.permissionStatus = granted ? .fullAccess : .denied
                    if granted { self?.fetchEvents(for: self?.selectedDate ?? Date()) }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.permissionStatus = granted ? .authorized : .denied
                    if granted { self?.fetchEvents(for: self?.selectedDate ?? Date()) }
                }
            }
        }
    }
    
    func fetchEvents(for date: Date) {
        var isAuthorized = false
        if #available(macOS 14.0, *) {
            isAuthorized = (permissionStatus == .fullAccess || permissionStatus == .authorized)
        } else {
            isAuthorized = (permissionStatus == .authorized)
        }
        
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        DispatchQueue.main.async {
            self.selectedDate = date
            self.eventsForSelectedDate = events.sorted { $0.startDate < $1.startDate }
        }
    }
    
    func timeUntilEvent(for event: EKEvent) -> String {
        let interval = event.startDate.timeIntervalSinceNow
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "in \(hours)h \(minutes)m" : "in \(minutes)m"
    }
}
