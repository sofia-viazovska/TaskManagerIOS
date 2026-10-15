//
//  TaskSortStrategy.swift
//  TaskManager
//
//  Поведінковий патерн: Strategy.
//
//  Задача:    змінювати спосіб сортування задач під час роботи застосунку
//             без if/else-ланцюжків усередині ViewModel.
//  Учасники:  Strategy — TaskSortStrategy; ConcreteStrategy — PrioritySortStrategy,
//             DueDateSortStrategy, TitleSortStrategy; Context — TaskListViewModel
//             (через SortOption обирає стратегію й делегує їй сортування).
//  Де:        TaskListViewModel.refresh().
//

import Foundation

/// Спільний інтерфейс усіх способів сортування.
protocol TaskSortStrategy {
    var name: String { get }
    func sorted(_ tasks: [TaskItem]) -> [TaskItem]
}

/// Спочатку найважливіші; за однакового пріоритету — за назвою (детермінований порядок).
struct PrioritySortStrategy: TaskSortStrategy {
    let name = "За пріоритетом"

    func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

/// Спочатку найближчий дедлайн; задачі без дедлайну — в кінці.
/// Тут `dueDate` (optional) обробляється через зіставлення зі зразком.
struct DueDateSortStrategy: TaskSortStrategy {
    let name = "За дедлайном"

    func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

/// За алфавітом.
struct TitleSortStrategy: TaskSortStrategy {
    let name = "За назвою"

    func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
