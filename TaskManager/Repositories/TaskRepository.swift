//
//  TaskRepository.swift
//  TaskManager
//
//  Абстракція доступу до даних. ViewModel залежить від цього протоколу,
//  а не від конкретного сховища (Dependency Inversion).
//

import Foundation

/// Контракт сховища задач.
///
/// Навмисно маленький (Interface Segregation): лише те, що потрібно застосунку.
/// Будь-яка реалізація має поводитись однаково (Liskov): після `saveTasks(x)`
/// наступний `loadTasks()` повертає `x` у тому ж порядку.
protocol TaskRepository {
    func loadTasks() throws -> [TaskItem]
    func saveTasks(_ tasks: [TaskItem]) throws
}
