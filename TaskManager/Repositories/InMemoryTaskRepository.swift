//
//  InMemoryTaskRepository.swift
//  TaskManager
//
//  Сховище в пам'яті: використовується для демо-режиму, #Preview і тестів.
//

import Foundation

/// Реалізація `TaskRepository`, що тримає задачі лише в оперативній пам'яті.
/// Дозволяє замінити реальне сховище без змін у ViewModel.
final class InMemoryTaskRepository: TaskRepository {
    private(set) var storedTasks: [TaskItem]
    /// Скільки разів викликали збереження — зручно перевіряти в тестах.
    private(set) var saveCount = 0

    init(initialTasks: [TaskItem] = []) {
        self.storedTasks = initialTasks
    }

    func loadTasks() throws -> [TaskItem] {
        storedTasks
    }

    func saveTasks(_ tasks: [TaskItem]) throws {
        storedTasks = tasks
        saveCount += 1
    }
}
