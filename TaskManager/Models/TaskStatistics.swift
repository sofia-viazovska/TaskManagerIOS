//
//  TaskStatistics.swift
//  TaskManager
//
//  Підсумкові числа для екрана «Статистика».
//

import Foundation

struct TaskStatistics: Equatable {
    let total: Int
    let completed: Int
    let overdue: Int
    let countsByPriority: [Priority: Int]

    var pending: Int { total - completed }

    /// Частка виконаних задач від 0 до 1 (для порожнього списку — 0, без ділення на нуль).
    var completionRatio: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    func count(for priority: Priority) -> Int {
        countsByPriority[priority] ?? 0
    }
}
