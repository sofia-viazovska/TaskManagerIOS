//
//  TaskListViewModel.swift
//  TaskManager
//
//  ViewModel (MVVM): стан екрана + команди від View. Тут немає SwiftUI-віджетів
//  і немає знання про конкретне сховище — лише TaskList (модель) та
//  абстракція TaskRepository, яку передають ззовні (Dependency Injection).
//

import Foundation
import Combine

final class TaskListViewModel: ObservableObject {
    // MARK: Стан для View (лише читання ззовні)

    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var errorMessage: String?

    var title: String { listName }
    var summary: String { taskList.describe() }

    // MARK: Залежності

    private let listName: String
    private let repository: any TaskRepository
    private var taskList: TaskList

    /// Залежність (`repository`) приходить через ініціалізатор — ViewModel
    /// сама не створює і не обирає сховище.
    init(listName: String, repository: any TaskRepository) {
        self.listName = listName
        self.repository = repository
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

    func addTask(title: String, priority: Priority) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Назва задачі не може бути порожньою"
            return
        }

        taskList.add(TaskItem(title: trimmed, priority: priority))
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

    private func persist() {
        do {
            try repository.saveTasks(taskList.tasks)
        } catch {
            errorMessage = "Не вдалося зберегти задачі: \(error.localizedDescription)"
        }
    }

    /// Перераховує те, що бачить View: спочатку найважливіші задачі.
    private func refresh() {
        tasks = taskList.tasks.sorted { $0.priority > $1.priority }
    }
}
