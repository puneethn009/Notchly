import SwiftUI
import SwiftData

struct NotchTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    
    @ObservedObject private var notchState = NotchState.shared
    
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newDueDate: Date? = nil
    @State private var newTagsString: String = ""
    @State private var newHasSoundReminder: Bool = false
    
    @FocusState private var isInputFocused: Bool
    @State private var selectedTab: Int = 0
    
    @State private var scrollMonitor: Any?
    
    private var sortedItems: [TodoItem] {
        todoItems.sorted {
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted && $1.isCompleted
            }
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.createdAt > $1.createdAt
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header — always visible, no frame cap
            HStack {
                Text("To-Do List")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !isAddingTask {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isAddingTask = true
                            isInputFocused = true
                            if notchState.extraHeight == 0 {
                                notchState.extraHeight = 200
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Circle().fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.top, 2)
            .padding(.bottom, 14)

            if isAddingTask {
                // Add Task Form — shown when user taps +
                VStack(spacing: 12) {
                    TextField("What do you need to do?", text: $newTaskTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .onSubmit {
                            addTask()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAddingTask = false
                            }
                        }
                    
                    HStack(spacing: 10) {
                        // Date/Time
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            
                            DatePicker("", selection: Binding(get: { newDueDate ?? Date() }, set: { newDueDate = $0 }), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .colorScheme(.dark)
                                .scaleEffect(0.9)
                                .frame(height: 24)
                                .clipped()
                            
                            if newDueDate != nil {
                                Button(action: { newDueDate = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        
                        // Tags
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            TextField("Tags (comma separated)", text: $newTagsString)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                    
                    Toggle("Play sound reminder when due", isOn: $newHasSoundReminder)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .toggleStyle(.switch)
                        .tint(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 0.5))

                    HStack(spacing: 10) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAddingTask = false
                                newTaskTitle = ""
                                newDueDate = nil
                                newTagsString = ""
                                newHasSoundReminder = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            addTask()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAddingTask = false
                            }
                        }) {
                            Text("Add Task")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                        }
                        .buttonStyle(.plain)
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))

            } else {
                let pendingItems = sortedItems.filter { !$0.isCompleted }
                let completedItems = sortedItems.filter { $0.isCompleted }

                // Segmented control — always visible, outside frame cap
                if !todoItems.isEmpty {
                    HStack(spacing: 0) {
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 } }) {
                            HStack(spacing: 5) {
                                Text("Pending")
                                Text("\(pendingItems.count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(selectedTab == 0 ? Color.blue.opacity(0.5) : Color.white.opacity(0.1)))
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(selectedTab == 0 ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)

                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 } }) {
                            HStack(spacing: 5) {
                                Text("Done")
                                Text("\(completedItems.count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(selectedTab == 1 ? Color.green.opacity(0.4) : Color.white.opacity(0.1)))
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(selectedTab == 1 ? Color.green.opacity(0.15) : Color.clear)
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))
                    .padding(.horizontal, 36)
                    .padding(.bottom, 14)
                }

                // List — the ONLY thing that is frame-capped
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if todoItems.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("Nothing to do!")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .padding(.top, 16)
                        } else if selectedTab == 0 {
                            if pendingItems.isEmpty {
                                Text("All tasks done! 🎉")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .padding(.top, 12)
                            } else {
                                ForEach(pendingItems) { item in
                                    TodoRowView(item: item, toggleCompletion: { toggleItem(item) }, deleteAction: { deleteItem(item) })
                                }
                            }
                        } else {
                            if completedItems.isEmpty {
                                Text("Nothing completed yet.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .padding(.top, 12)
                            } else {
                                ForEach(completedItems) { item in
                                    TodoRowView(item: item, toggleCompletion: { toggleItem(item) }, deleteAction: { deleteItem(item) })
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: notchState.extraHeight > 0 ? 200 : 50)
                .clipped()
            }
        }
        .onAppear {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if NotchState.shared.selectedPage == .todo && NotchState.shared.isHovering {
                    handleScroll(event: event)
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    private func handleScroll(event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        if deltaY < -2 && notchState.extraHeight == 0 && !todoItems.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                notchState.extraHeight = 180
            }
        } else if deltaY > 15 && notchState.extraHeight > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                notchState.extraHeight = 0
                isAddingTask = false
                newTaskTitle = ""
            }
        }
    }

    
    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let parsedTags = newTagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        let newItem = TodoItem(title: title, dueDate: newDueDate, reminderTime: newDueDate, tags: parsedTags, hasSoundReminder: newHasSoundReminder)
        modelContext.insert(newItem)
        try? modelContext.save()
        
        newTaskTitle = ""
        newDueDate = nil
        newTagsString = ""
        newHasSoundReminder = false
        
        if newHasSoundReminder {
            TodoReminderManager.shared.scheduleReminders()
        }
    }
    
    private func toggleItem(_ item: TodoItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            item.isCompleted.toggle()
            if item.isCompleted && SettingsManager.shared.todoCompletionSound {
                NSSound(named: "Glass")?.play()
            }
            try? modelContext.save()
        }
    }
    
    private func deleteItem(_ item: TodoItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
}

struct TodoRowView: View {
    var item: TodoItem
    var toggleCompletion: () -> Void
    var deleteAction: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Larger tappable area for the completion circle
            Button(action: toggleCompletion) {
                ZStack {
                    Circle()
                        .stroke(item.isCompleted ? Color.green.opacity(0.6) : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .frame(width: 32, height: 32) // Large invisible hit area
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(item.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                    .strikethrough(item.isCompleted, color: .white.opacity(0.3))
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    if let due = item.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: item.hasSoundReminder ? "bell.fill" : "calendar")
                            Text(due, style: .time)
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(due < Date() && !item.isCompleted ? .red.opacity(0.8) : .white.opacity(0.4))
                    }
                    
                    if !item.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 8, weight: .semibold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.blue.opacity(0.3)))
                                    .foregroundColor(.blue.opacity(0.8))
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            if isHovering {
                Button(action: deleteAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.isCompleted ? Color.white.opacity(0.03) : Color.white.opacity(isHovering ? 0.07 : 0.04))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

class TodoReminderManager {
    static let shared = TodoReminderManager()
    
    private var timer: Timer?
    
    @MainActor
    private var modelContext: ModelContext {
        PersistenceController.shared.container.mainContext
    }
    
    func scheduleReminders() {
        start()
    }
    
    func start() {
        guard timer == nil else { return }
        
        // Check every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkForDueReminders()
        }
        // Also check immediately
        checkForDueReminders()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private var soundLooper: Timer?
    private var lastOverduePulseDate: Date? = nil
    
    private func checkForDueReminders() {
        Task { @MainActor in
            let now = Date()
            
            // 1. Check for active ringing alarms
            if NotchState.shared.activeTaskReminderId == nil {
                let alertDescriptor = FetchDescriptor<TodoItem>(
                    predicate: #Predicate { !$0.isCompleted && $0.hasSoundReminder }
                )
                
                do {
                    let items = try modelContext.fetch(alertDescriptor)
                    for item in items {
                        if let reminderTime = item.reminderTime, reminderTime <= now {
                            // Trigger the custom notch alarm
                            NotchState.shared.activeTaskReminderId = item.id
                            NotchState.shared.activeTaskReminderTitle = item.title
                            NotchState.shared.activeTaskReminderTags = item.tags
                            
                            // Expand notch
                            NotchState.shared.isExpanded = true
                            NotchState.shared.selectedPage = .todo
                            
                            // Start looping sound
                            startAlarmSound()
                            break // Handle one alarm at a time
                        }
                    }
                } catch {
                    print("Failed to fetch ringing reminders: \(error)")
                }
            }
            
            // 2. Check for overdue sticky indicator (all overdue tasks, regardless of sound flag)
            do {
                if SettingsManager.shared.todoShowOverdue {
                    let overdueDescriptor = FetchDescriptor<TodoItem>(
                        predicate: #Predicate { !$0.isCompleted }
                    )
                    let pendingItems = try modelContext.fetch(overdueDescriptor)
                    
                    let hasOverdue = pendingItems.contains { item in
                        if let reminderTime = item.reminderTime {
                            return reminderTime <= now && item.id != NotchState.shared.activeTaskReminderId
                        }
                        return false
                    }
                    NotchState.shared.hasOverdueTodo = hasOverdue
                    
                    if hasOverdue && !NotchState.shared.isExpanded && NotchState.shared.activeTaskReminderId == nil {
                        let interval = Double(SettingsManager.shared.todoOverdueReminderInterval) * 60.0
                        if lastOverduePulseDate == nil || now.timeIntervalSince(lastOverduePulseDate!) >= interval {
                            lastOverduePulseDate = now
                            NotchState.shared.isOverdueReminderActive = true
                            NotchState.shared.evaluateStickyPriority()
                            
                            NotchState.shared.overdueDisplayTimer?.invalidate()
                            NotchState.shared.overdueDisplayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                                Task { @MainActor in
                                    NotchState.shared.isOverdueReminderActive = false
                                    NotchState.shared.evaluateStickyPriority()
                                }
                            }
                        }
                    } else if !hasOverdue {
                        lastOverduePulseDate = nil
                        if NotchState.shared.isOverdueReminderActive {
                            NotchState.shared.isOverdueReminderActive = false
                            NotchState.shared.evaluateStickyPriority()
                        }
                    }
                    
                } else {
                    NotchState.shared.hasOverdueTodo = false
                    lastOverduePulseDate = nil
                    if NotchState.shared.isOverdueReminderActive {
                        NotchState.shared.isOverdueReminderActive = false
                        NotchState.shared.evaluateStickyPriority()
                    }
                }
            } catch {
                print("Failed to fetch overdue items: \(error)")
            }

        }
    }
    
    private func startAlarmSound() {
        soundLooper?.invalidate()
        NSSound(named: "Glass")?.play()
        soundLooper = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            NSSound(named: "Glass")?.play()
        }
    }
    
    @MainActor
    func completeActiveAlarm() {
        guard let id = NotchState.shared.activeTaskReminderId else { return }
        
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        if let item = try? modelContext.fetch(descriptor).first {
            item.isCompleted = true
            item.hasSoundReminder = false
            try? modelContext.save()
        }
        
        cancelAlarm()
    }
    
    @MainActor
    func cancelAlarm() {
        // Stop sound
        soundLooper?.invalidate()
        soundLooper = nil
        
        // Remove active state
        let id = NotchState.shared.activeTaskReminderId
        if let id = id {
            let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
            if let item = try? modelContext.fetch(descriptor).first {
                item.hasSoundReminder = false
                try? modelContext.save()
            }
        }
        
        NotchState.shared.activeTaskReminderId = nil
        NotchState.shared.isExpanded = false
        
        // Immediately refresh overdue state
        checkForDueReminders()
    }
}
