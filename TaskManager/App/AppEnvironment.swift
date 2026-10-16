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

    /// Роутер не залежить від даних — створюється окремо і живе стільки ж, скільки застосунок.
    static func makeRouter() -> AppRouter {
        AppRouter()
    }

    // MARK: Мережа (практична 4)

    /// Базова адреса реального API (JSONPlaceholder, без авторизації).
    static let apiBaseURL = URL(string: "https://jsonplaceholder.typicode.com")!

    /// ViewModel екрана імпорту. Сервіс приходить ззовні (DI): у застосунку — реальний
    /// або mock за аргументом запуску, у тестах і превʼю — будь-який власний.
    static func makeServerTasksViewModel(
        service: (any TodoService)? = nil,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ServerTasksViewModel {
        ServerTasksViewModel(service: service ?? makeTodoService(arguments: arguments))
    }

    /// Вибір реалізації сервісу за аргументами запуску (Edit Scheme → Run → Arguments).
    /// Без аргументів — реальний запит до JSONPlaceholder. Аргументи `-network-*`
    /// підставляють керований mock, щоб відтворити будь-який стан без залежності від мережі:
    ///   -network-empty     порожня відповідь `[]`       → стан «Немає даних»
    ///   -network-error     HTTP 500                     → стан «Помилка» (HTTP)
    ///   -network-offline   немає інтернету              → стан «Помилка» (транспорт)
    ///   -network-decoding  200, але невірний формат     → стан «Помилка» (декодування)
    ///   -network-flaky     перший запит 503, далі успіх → перевірка кнопки «Повторити»
    ///   -network-slow      успіх із затримкою 3 с       → добре видно стан «Завантаження»
    static func makeTodoService(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any TodoService {
        func has(_ flag: String) -> Bool { arguments.contains(flag) }

        if has("-network-empty") {
            return MockTodoService(script: [.todos([])])
        }
        if has("-network-error") {
            return MockTodoService(script: [.failure(.httpStatus(500))])
        }
        if has("-network-offline") {
            return MockTodoService(script: [.failure(.transport(.notConnectedToInternet))])
        }
        if has("-network-decoding") {
            return MockTodoService(script: [.failure(.decoding("немає поля «title»"))])
        }
        if has("-network-flaky") {
            return MockTodoService(script: [.failure(.httpStatus(503)), .todos(RemoteTodo.samples)])
        }
        if has("-network-slow") {
            return MockTodoService(script: [.todos(RemoteTodo.samples)], delay: .seconds(3))
        }
        return makeRemoteTodoService()
    }

    /// Реальний сервіс: URLSession із власною конфігурацією (таймаути, без очікування зв'язку).
    static func makeRemoteTodoService() -> RemoteTodoService {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Endpoint.timeout
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        return RemoteTodoService(client: APIClient(baseURL: apiBaseURL, transport: session))
    }

    // MARK: Сховище

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
            TaskItemBuilder(title: "Здати лабу 3")
                .withPriority(.high)
                .dueIn(days: 1, from: now)
                .withNotes("Навігація: Router + NavigationStack. Перевірити на двох розмірах екрана, зробити скріншоти й тег practical-3."),
            TaskItemBuilder(title: "Прочитати про NavigationStack")
                .withPriority(.medium)
                .dueIn(days: 3, from: now)
                .withNotes("Документація Apple: NavigationStack, NavigationPath, navigationDestination(for:)."),
            TaskItemBuilder(title: "Повторити MVVM")
                .withPriority(.medium)
                .dueIn(days: -1, from: now),
            TaskItemBuilder(title: "Налаштувати git remote")
                .withPriority(.low)
                .markedDone()
        ]
        return builders.compactMap { try? $0.build() }
    }
}
