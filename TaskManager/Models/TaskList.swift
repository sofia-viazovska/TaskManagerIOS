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

    func describe() -> String {
        "\(name): \(tasks.count) задач, з них виконано \(completedCount)"
    }
}
