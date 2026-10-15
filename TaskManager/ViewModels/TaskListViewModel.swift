//
//  TaskListViewModel.swift
//  TaskManager
//
//  ViewModel (MVVM): єдине джерело правди про задачі для всіх екранів.
//  Екрани передають між собою лише ідентифікатор задачі, а актуальні дані
//  беруть звідси — тому після створення чи редагування всі екрани оновлюються
//  самі, без повернення результату «вручну».
//
//  Тут немає SwiftUI-віджетів і немає навігації (за неї відповідає AppRouter).
//  Залежності (сховище, годинник) приходять через init.
//
//  Патерни: Builder (створення/оновлення задачі), Strategy (сортування).
//

import Foundation
import Combine

/// Помилки редагування, які не пов'язані з валідацією полів.
nonisolated enum TaskEditingError: Error, LocalizedError, Equatable {
    case taskNotFound

    var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Задачу не знайдено — можливо, її вже видалено"
        }
    }
}

final class TaskListViewModel: ObservableObject {
    // MARK: Стан для View

    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var errorMessage: String?

    /// Налаштування вигляду: зміна одразу перераховує список.
    @Published var sortOption: SortOption = .priority {
        didSet { refresh() }
    }
    @Published var showOnlyPending = false {
        didSet { refresh() }
    }

    var title: String { listName }
    var summary: String { taskList.describe() }
    var statistics: TaskStatistics { taskList.statistics(now: now()) }

    /// Запропонований дедлайн для нової задачі: завтра від «зараз» (годинник ін'єктований).
    var defaultDeadline: Date { now().addingTimeInterval(24 * 60 * 60) }

    // MARK: Залежності

    private let listName: String
    private let repository: any TaskRepository
    private let now: () -> Date
    private var taskList: TaskList

    init(listName: String, repository: any TaskRepository, now: @escaping () -> Date) {
        self.listName = listName
        self.repository = repository
        self.now = now
        self.taskList = TaskList(name: listName)
    }

    // MARK: Запити (читання для екранів)

    func task(id: TaskItem.ID) -> TaskItem? {
        taskList.task(id: id)
    }

    func isOverdue(_ task: TaskItem) -> Bool {
        task.isOverdue(at: now())
    }

    /// Чернетка для форми редагування. `nil` — задачі вже немає.
    func draft(for id: TaskItem.ID) -> TaskDraft? {
        guard let task = taskList.task(id: id) else { return nil }
        return TaskDraft(title: task.title, priority: task.priority, dueDate: task.dueDate, notes: task.notes)
    }

    // MARK: Команди (їх викликають екрани)

    func load() {
        do {
            let stored = try repository.loadTasks()
            taskList = TaskList(name: listName, tasks: stored)
            errorMessage = nil
        } catch {
            errorMessage = "Не вдалося завантажити задачі: \(error.localizedDescription)"
        }
        refresh()
    }

    /// Створює задачу з чернетки. Помилку валідації кидає далі — її показує форма,
    /// яка й викликала команду, а не загальний банер списку.
    func create(_ draft: TaskDraft) throws {
        let task = try builder(for: draft).build()

        taskList.add(task)
        errorMessage = nil
        persist()
        refresh()
    }

    /// Оновлює наявну задачу: id і стан «виконано» зберігаються, решта — з чернетки.
    func update(id: TaskItem.ID, with draft: TaskDraft) throws {
        guard let existing = taskList.task(id: id) else {
            throw TaskEditingError.taskNotFound
        }
        let updated = try builder(for: draft)
            .withID(existing.id)
            .markedDone(existing.isDone)
            .build()

        taskList.update(updated)
        errorMessage = nil
        persist()
        refresh()
    }

    func delete(id: TaskItem.ID) {
        guard taskList.remove(id: id) else { return }
        errorMessage = nil
        persist()
        refresh()
    }

    func toggleDone(id: TaskItem.ID) {
        guard taskList.toggleDone(id: id) else { return }
        errorMessage = nil
        persist()
        refresh()
    }

    // MARK: Приватна логіка

    /// Builder: накопичуємо значення з чернетки, а валідацію виконує build().
    private func builder(for draft: TaskDraft) -> TaskItemBuilder {
        TaskItemBuilder(title: draft.title)
            .withPriority(draft.priority)
            .withDueDate(draft.dueDate)
            .withNotes(draft.notes)
    }

    private func persist() {
        do {
            try repository.saveTasks(taskList.tasks)
        } catch {
            errorMessage = "Не вдалося зберегти задачі: \(error.localizedDescription)"
        }
    }

    /// Фільтрація (модель) + сортування (Strategy) → те, що бачить View.
    private func refresh() {
        let base = showOnlyPending ? taskList.pendingTasks() : taskList.tasks
        tasks = sortOption.strategy.sorted(base)
    }
}
