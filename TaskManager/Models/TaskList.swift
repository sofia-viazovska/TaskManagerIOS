//
//  TaskList.swift
//  TaskManager
//
//  Доменна модель: колекція задач і бізнес-правила роботи з нею.
//
//  Лаба 2: клас більше НЕ є ObservableObject і не знає про SwiftUI/Combine.
//  Стан для екрана тепер публікує ViewModel, а зберігання — Repository.
//  TaskList відповідає лише за правила: додати задачу, перемкнути статус,
//  вибрати невиконані.
//

import Foundation

/// Список задач.
///
/// Залишається `class` (семантика посилання, як у лабі 1): ViewModel тримає
/// один екземпляр і змінює його in-place, а Repository отримує знімок
/// масиву `tasks` (масив — значення, тому знімок незалежний від подальших змін).
final class TaskList: Describable {
    let name: String
    private(set) var tasks: [TaskItem]

    init(name: String, tasks: [TaskItem] = []) {
        self.name = name
        self.tasks = tasks
    }

    func add(_ task: TaskItem) {
        tasks.append(task)
    }

    /// Знаходить задачу за ідентифікатором — екрани передають лише id,
    /// а актуальні дані беруть звідси.
    func task(id: TaskItem.ID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    /// Замінює збережену задачу з тим самим id. `false` — такої задачі немає.
    @discardableResult
    func update(_ task: TaskItem) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return false }
        tasks[index] = task
        return true
    }

    /// Видаляє задачу за id. `false` — такої задачі немає.
    @discardableResult
    func remove(id: TaskItem.ID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return false }
        tasks.remove(at: index)
        return true
    }

    /// Перемикає стан "виконано" за id.
    /// Повертає `false`, якщо задачі з таким id немає (`guard let` — безпечне розгортання).
    @discardableResult
    func toggleDone(id: TaskItem.ID) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return false }
        tasks[index].isDone.toggle()
        return true
    }

    /// Невиконані задачі (лише фільтрація; порядок визначає той, хто викликає).
    func pendingTasks() -> [TaskItem] {
        tasks.filter { !$0.isDone }
    }

    /// Заголовки всіх задач — приклад `map`.
    var titles: [String] {
        tasks.map(\.title)
    }

    var completedCount: Int {
        tasks.filter(\.isDone).count
    }

    /// Підсумки для екрана статистики. Поточний час передається ззовні.
    func statistics(now: Date) -> TaskStatistics {
        var countsByPriority: [Priority: Int] = [:]
        for task in tasks {
            countsByPriority[task.priority, default: 0] += 1
        }

        return TaskStatistics(
            total: tasks.count,
            completed: completedCount,
            overdue: tasks.filter { $0.isOverdue(at: now) }.count,
            countsByPriority: countsByPriority
        )
    }

    func describe() -> String {
        "\(name): \(tasks.count) задач, з них виконано \(completedCount)"
    }
}
