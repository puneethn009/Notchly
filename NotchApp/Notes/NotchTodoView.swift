import SwiftUI
import SwiftData

struct NotchTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    
    @ObservedObject private var notchState = NotchState.shared
    
    @State private var newTaskTitle: String = ""
    @State private var isAddingTask: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var selectedTab: Int = 0
    
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
                                notchState.extraHeight = 180
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

                if notchState.extraHeight > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            notchState.extraHeight = 0
                            isAddingTask = false
                            newTaskTitle = ""
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(5)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if isAddingTask {
                // Add Task Form — shown when user taps +
                VStack(spacing: 10) {
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
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isAddingTask = false
                                newTaskTitle = ""
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
                    .padding(.bottom, 6)
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

                // Expand chevron
                if notchState.extraHeight == 0 && !todoItems.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            notchState.extraHeight = 180
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.04))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    
    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let newItem = TodoItem(title: title)
        modelContext.insert(newItem)
        try? modelContext.save()
        
        newTaskTitle = ""
    }
    
    private func toggleItem(_ item: TodoItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            item.isCompleted.toggle()
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(item.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                    .strikethrough(item.isCompleted, color: .white.opacity(0.3))
                    .lineLimit(2)
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
