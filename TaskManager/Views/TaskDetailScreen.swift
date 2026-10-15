//
//  TaskDetailScreen.swift
//  TaskManager
//
//  Екран 2: деталі задачі (push зі списку). Отримує лише `taskID`, а дані
//  щоразу читає з ViewModel — тому після редагування в модальному вікні
//  екран оновлюється сам, без «повернення результату» вручну.
//

import SwiftUI

struct TaskDetailScreen: View {
    let taskID: TaskItem.ID
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var router: AppRouter

    // Суто UI-стан цього екрана: живе в самому View і зникає разом з ним.
    @State private var isNotesExpanded = false
    @State private var showDeleteConfirmation = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let task = viewModel.task(id: taskID) {
                content(for: task)
            } else {
                ContentUnavailableView(
                    "Задачу не знайдено",
                    systemImage: "questionmark.folder",
                    description: Text("Можливо, її вже видалено.")
                )
            }
        }
        .navigationTitle("Деталі")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.task(id: taskID) != nil {
                    Button("Змінити") {
                        router.presentEdit(taskID)
                    }
                }
            }
        }
        .confirmationDialog(
            "Видалити задачу?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Видалити", role: .destructive) {
                deleteTask()
            }
            Button("Скасувати", role: .cancel) {}
        } message: {
            Text("Цю дію не можна скасувати.")
        }
    }

    // MARK: Вміст

    private func content(for task: TaskItem) -> some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 4) {
                    CompletionCheckbox(isDone: task.isDone) {
                        Motion.perform(reduceMotion: reduceMotion, Motion.checkbox) {
                            viewModel.toggleDone(id: taskID)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.title3.bold())
                            .strikethrough(task.isDone)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(task.isDone ? "Виконано" : "У роботі")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                    }
                    .padding(.top, 8)
                }
                .animation(Motion.animation(Motion.checkbox, reduceMotion: reduceMotion), value: task.isDone)
            }

            Section("Інформація") {
                LabeledContent("Пріоритет") {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                        Text(task.priority.displayName)
                    }
                    .foregroundStyle(task.priority.color)
                }
                LabeledContent("Дедлайн") {
                    deadlineText(for: task)
                }
            }

            Section("Нотатки") {
                notesBlock(for: task)
            }

            Section {
                Button("Видалити задачу", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
    }

    @ViewBuilder
    private func deadlineText(for task: TaskItem) -> some View {
        if let dueDate = task.dueDate {
            let text = dueDate.formatted(date: .abbreviated, time: .shortened)
            if viewModel.isOverdue(task) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Прострочено · \(text)")
                }
                .foregroundStyle(.red)
            } else {
                Text(text)
            }
        } else {
            Text("Без дедлайну")
                .foregroundStyle(.secondary)
        }
    }

    /// Блок нотаток, що розгортається. Анімація залежить від стану `isNotesExpanded`:
    /// стрілка повертається, текст плавно з'являється.
    @ViewBuilder
    private func notesBlock(for task: TaskItem) -> some View {
        if task.notes.isEmpty {
            Text("Нотаток немає")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Motion.perform(reduceMotion: reduceMotion, Motion.expand) {
                        isNotesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isNotesExpanded ? "Сховати нотатки" : "Показати нотатки")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isNotesExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isNotesExpanded ? "Розгорнуто" : "Згорнуто")

                if isNotesExpanded {
                    Text(task.notes)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: Дії

    /// Спочатку крок назад, потім видалення — користувач повертається на список,
    /// а не бачить «порожній» екран видаленої задачі.
    private func deleteTask() {
        router.pop()
        viewModel.delete(id: taskID)
    }
}

#Preview {
    let viewModel = AppEnvironment.makeDemoViewModel()
    viewModel.load()
    let firstID = viewModel.tasks.first?.id ?? UUID()
    return NavigationStack {
        TaskDetailScreen(taskID: firstID, viewModel: viewModel, router: AppEnvironment.makeRouter())
    }
}
