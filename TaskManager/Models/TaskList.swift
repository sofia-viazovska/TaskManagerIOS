//
//  TaskList.swift
//  TaskManager
//
//  Колекція задач і логіка роботи з нею.
//

import Foundation
import Combine

/// Список задач.
///
/// `TaskList` навмисно зроблена `class`, а не `struct`: це семантика
/// посилання. SwiftUI-екран, дії користувача та демонстраційний сценарій
/// мають працювати з ОДНИМ і тим самим списком — якщо передати TaskList
/// у кілька місць коду, усі вони бачитимуть одні й ті самі задачі та їх
/// зміни, на відміну від struct, де кожна копія була б окремою.
///
/// Конформність до `ObservableObject` + `@Published` дозволяє SwiftUI
/// автоматично оновлювати екран при зміні задач.
final class TaskList: ObservableObject, Describable {
    let name: String
    @Published private(set) var tasks: [TaskItem] = []

    init(name: String) {
        self.name = name
    }

    func add(_ task: TaskItem) {
        tasks.append(task)
    }

    /// Перемикає стан "виконано" для задачі за її id.
    /// `guard let` — безпечне розгортання: якщо задачі з таким id немає,
    /// метод просто завершується, без падіння програми.
    func toggleDone(id: TaskItem.ID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone.toggle()
    }

    /// Невиконані задачі, відсортовані за пріоритетом (найважливіші перші).
    /// Демонструє обробку колекції: `filter` + `sorted`.
    func pendingTasks() -> [TaskItem] {
        tasks
            .filter { !$0.isDone }
            .sorted { $0.priority > $1.priority }
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
