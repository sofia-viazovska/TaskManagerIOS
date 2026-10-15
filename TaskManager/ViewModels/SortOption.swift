//
//  SortOption.swift
//  TaskManager
//
//  Варіанти сортування, які бачить користувач, і відповідні їм стратегії.
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case priority
    case dueDate
    case title

    var id: String { rawValue }

    /// Конкретна стратегія для цього варіанта. Щоб додати новий спосіб
    /// сортування, потрібен новий тип-стратегія і один case тут;
    /// код ViewModel не змінюється (Open/Closed).
    var strategy: any TaskSortStrategy {
        switch self {
        case .priority: return PrioritySortStrategy()
        case .dueDate: return DueDateSortStrategy()
        case .title: return TitleSortStrategy()
        }
    }
}
