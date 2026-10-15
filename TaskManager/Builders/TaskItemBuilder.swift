//
//  TaskItemBuilder.swift
//  TaskManager
//
//  Породжувальний патерн: Builder.
//
//  Задача:    створювати TaskItem покроково (багато необов'язкових параметрів)
//             і гарантувати, що в застосунок потрапляє лише валідна задача.
//  Учасники:  Product — TaskItem; Builder — TaskItemBuilder (ланцюжок with…/dueIn);
//             Director — TaskListViewModel і AppEnvironment (викликають builder).
//  Де:        TaskListViewModel.addTask, AppEnvironment.demoTasks.
//

import Foundation

/// Помилки валідації під час побудови задачі.
nonisolated enum TaskItemBuilderError: Error, LocalizedError, Equatable {
    case emptyTitle
    case titleTooLong(limit: Int)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Назва задачі не може бути порожньою"
        case .titleTooLong(let limit):
            return "Назва задачі задовга (максимум \(limit) символів)"
        }
    }
}

/// Fluent builder для `TaskItem`. Це значення (struct): кожен виклик `with…`
/// повертає нову копію, тому один «шаблон» можна безпечно розгалужувати.
struct TaskItemBuilder {
    static let maxTitleLength = 100

    private var title: String
    private var priority: Priority = .medium
    private var dueDate: Date?
    private var isDone = false

    init(title: String) {
        self.title = title
    }

    func withPriority(_ value: Priority) -> TaskItemBuilder {
        var copy = self
        copy.priority = value
        return copy
    }

    func withDueDate(_ value: Date?) -> TaskItemBuilder {
        var copy = self
        copy.dueDate = value
        return copy
    }

    /// Дедлайн через `days` днів від переданого моменту `now`.
    /// Поточний час передається ззовні, а не береться з `Date()` всередині —
    /// так результат детермінований і легко перевіряється тестом.
    /// (День тут — 24 години; для застосунку-демо цього достатньо.)
    func dueIn(days: Int, from now: Date) -> TaskItemBuilder {
        withDueDate(now.addingTimeInterval(TimeInterval(days) * 24 * 60 * 60))
    }

    func markedDone(_ value: Bool = true) -> TaskItemBuilder {
        var copy = self
        copy.isDone = value
        return copy
    }

    /// Валідує накопичені значення й створює задачу.
    func build() throws -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw TaskItemBuilderError.emptyTitle
        }
        guard trimmed.count <= Self.maxTitleLength else {
            throw TaskItemBuilderError.titleTooLong(limit: Self.maxTitleLength)
        }

        return TaskItem(title: trimmed, priority: priority, dueDate: dueDate, isDone: isDone)
    }
}
