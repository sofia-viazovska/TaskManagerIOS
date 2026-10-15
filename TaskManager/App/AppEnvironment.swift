//
//  AppEnvironment.swift
//  TaskManager
//
//  Composition root: єдине місце, де обираються конкретні реалізації
//  залежностей і збираються компоненти докупи.
//

import Foundation

enum AppEnvironment {
    static func makeViewModel() -> TaskListViewModel {
        let repository = InMemoryTaskRepository(initialTasks: demoTasks())
        return TaskListViewModel(listName: "Навчання", repository: repository)
    }

    private static func demoTasks() -> [TaskItem] {
        [
            TaskItem(title: "Здати лабу 2", priority: .high),
            TaskItem(title: "Прочитати про MVVM", priority: .medium),
            TaskItem(title: "Налаштувати git remote", priority: .low, isDone: true)
        ]
    }
}
