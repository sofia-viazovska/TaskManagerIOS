//
//  AppEnvironment.swift
//  TaskManager
//
//  Composition root: єдине місце, де обираються конкретні реалізації
//  залежностей (сховище, годинник) і збираються компоненти докупи.
//  Усі «глобальні» джерела — UserDefaults.standard, Date(), аргументи запуску —
//  читаються лише тут і передаються вниз явно.
//

import Foundation

enum AppEnvironment {
    /// Звичайний запуск — реальне сховище. Запуск з аргументом `-demo`
    /// (Edit Scheme → Run → Arguments) — демо-режим із даними в пам'яті.
    static func makeViewModel(
        isDemo: Bool = ProcessInfo.processInfo.arguments.contains("-demo")
    ) -> TaskListViewModel {
        isDemo ? makeDemoViewModel() : makeLiveViewModel()
    }

    /// Реальна залежність: Adapter над UserDefaults.
    static func makeLiveViewModel() -> TaskListViewModel {
        let repository = UserDefaultsTaskRepository(defaults: .standard, key: "tasks.v1")
        return TaskListViewModel(listName: "Навчання", repository: repository, now: { Date() })
    }

    /// Демонстраційна залежність: сховище в пам'яті з готовими задачами.
    /// Те саме ViewModel без жодних змін — це і є заміна реалізації.
    static func makeDemoViewModel(now: @escaping () -> Date = { Date() }) -> TaskListViewModel {
        let repository = InMemoryTaskRepository(initialTasks: demoTasks(now: now()))
        return TaskListViewModel(listName: "Навчання (демо)", repository: repository, now: now)
    }

    private static func demoTasks(now: Date) -> [TaskItem] {
        let builders: [TaskItemBuilder] = [
            TaskItemBuilder(title: "Здати лабу 2").withPriority(.high).dueIn(days: 1, from: now),
            TaskItemBuilder(title: "Прочитати про MVVM").withPriority(.medium).dueIn(days: 3, from: now),
            TaskItemBuilder(title: "Налаштувати git remote").withPriority(.low).markedDone()
        ]
        return builders.compactMap { try? $0.build() }
    }
}
