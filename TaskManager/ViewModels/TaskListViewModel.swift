//
//  TaskListViewModel.swift
//  TaskManager
//
//  ViewModel (MVVM): стан екрана + команди від View. Тут немає SwiftUI-віджетів
//  і немає знання про конкретне сховище чи системний годинник — лише TaskList
//  (модель), абстракція TaskRepository та функція `now`, які передають ззовні
//  (Dependency Injection).
//
//  Патерни: Builder (створення задачі в addTask), Strategy (сортування в refresh).
//

import Foundation
import Combine

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

    // MARK: Команди (їх викликає View)

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

    /// `dueInDays == nil` — задача без дедлайну.
    func addTask(title: String, priority: Priority, dueInDays: Int? = nil) {
        do {
            // Builder: накопичуємо параметри, а валідацію виконує build().
            var builder = TaskItemBuilder(title: title).withPriority(priority)
            if let days = dueInDays {
                builder = builder.dueIn(days: days, from: now())
            }
            let task = try builder.build()

            taskList.add(task)
            errorMessage = nil
            persist()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleDone(id: TaskItem.ID) {
        guard taskList.toggleDone(id: id) else { return }
        errorMessage = nil
        persist()
        refresh()
    }

    // MARK: Приватна логіка

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
