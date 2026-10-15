//
//  UserDefaultsTaskRepository.swift
//  TaskManager
//
//  Структурний патерн: Adapter.
//
//  Задача:    застосунок очікує інтерфейс TaskRepository (задачі як [TaskItem]),
//             а наявний системний API UserDefaults працює з байтами (Data) за ключем.
//             Адаптер перекладає одне в інше.
//  Учасники:  Target — TaskRepository; Adaptee — UserDefaults + JSONEncoder/Decoder;
//             Adapter — UserDefaultsTaskRepository; Client — TaskListViewModel.
//  Де:        AppEnvironment.makeLiveViewModel().
//

import Foundation

/// Формат запису задачі у сховищі. Окремий від `TaskItem`: доменна модель не
/// мусить знати про JSON, а зміна формату зберігання не ламає модель.
nonisolated struct TaskRecord: Codable, Equatable {
    var id: UUID
    var title: String
    var priority: String
    var dueDate: Date?
    var isDone: Bool
    /// Додано в лабі 3. Optional зі значенням за замовчуванням: записи, збережені
    /// раніше (без цього поля), як і раніше успішно читаються.
    var notes: String? = nil
}

/// Адаптер `UserDefaults` до `TaskRepository`.
final class UserDefaultsTaskRepository: TaskRepository {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// `UserDefaults` і ключ передаються ззовні (без прихованого `.standard`):
    /// тест може створити ізольоване сховище через `UserDefaults(suiteName:)`.
    init(defaults: UserDefaults, key: String) {
        self.defaults = defaults
        self.key = key
    }

    func loadTasks() throws -> [TaskItem] {
        // Ключа ще немає (перший запуск) — це не помилка, а порожній список.
        guard let data = defaults.data(forKey: key) else { return [] }

        let records = try decoder.decode([TaskRecord].self, from: data)
        return records.map { record in
            TaskItem(
                id: record.id,
                title: record.title,
                // Невідоме значення (наприклад, зі старої версії) — безпечний варіант за замовчуванням.
                priority: Priority(rawValue: record.priority) ?? .medium,
                dueDate: record.dueDate,
                isDone: record.isDone,
                notes: record.notes ?? ""
            )
        }
    }

    func saveTasks(_ tasks: [TaskItem]) throws {
        let records = tasks.map { task in
            TaskRecord(
                id: task.id,
                title: task.title,
                priority: task.priority.rawValue,
                dueDate: task.dueDate,
                isDone: task.isDone,
                notes: task.notes
            )
        }
        defaults.set(try encoder.encode(records), forKey: key)
    }
}
