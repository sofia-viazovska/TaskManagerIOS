//
//  MockTodoService.swift
//  TaskManager
//
//  Керований сервіс-заглушка. Заздалегідь заданий «сценарій» відповідей:
//  кожен виклик бере наступний результат (останній повторюється).
//  Використовується в двох місцях:
//  • запуск з аргументами `-network-empty`, `-network-error` тощо (див. AppEnvironment);
//  • юніт-тести (порожня відповідь, помилки, «збій, а потім успіх» для кнопки «Повторити»).
//

import Foundation

final class MockTodoService: TodoService {
    enum Outcome {
        case todos([RemoteTodo])
        case failure(NetworkError)
    }

    private var script: [Outcome]
    private let delay: Duration

    /// Параметри всіх викликів — тест може перевірити, що саме запитав екран.
    private(set) var requests: [(userID: Int, limit: Int)] = []

    var callCount: Int { requests.count }

    init(script: [Outcome], delay: Duration = .zero) {
        self.script = script
        self.delay = delay
    }

    func fetchTodos(userID: Int, limit: Int) async throws -> [RemoteTodo] {
        requests.append((userID, limit))

        // Штучна затримка, щоб побачити стан «Завантаження». Скасовується разом із запитом.
        if delay > .zero {
            try await Task.sleep(for: delay)
        }

        let outcome: Outcome
        if script.count > 1 {
            outcome = script.removeFirst()
        } else {
            outcome = script.first ?? .todos([])
        }

        switch outcome {
        case .todos(let todos):
            return todos
        case .failure(let error):
            throw error
        }
    }
}

extension RemoteTodo {
    /// Приклади для демо-режиму та тестів (у форматі, як у JSONPlaceholder).
    static let samples: [RemoteTodo] = [
        RemoteTodo(userID: 1, id: 1, title: "delectus aut autem", completed: false),
        RemoteTodo(userID: 1, id: 2, title: "quis ut nam facilis et officia qui", completed: false),
        RemoteTodo(userID: 1, id: 3, title: "fugiat veniam minus", completed: false),
        RemoteTodo(userID: 1, id: 4, title: "et porro tempora", completed: true),
        RemoteTodo(userID: 1, id: 5, title: "laboriosam mollitia et enim quasi adipisci quia provident illum", completed: false)
    ]
}
