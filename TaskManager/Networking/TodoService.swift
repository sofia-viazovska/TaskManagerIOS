//
//  TodoService.swift
//  TaskManager
//
//  Абстракція мережевого сервісу. ViewModel знає лише про цей протокол:
//  що саме відбувається «під капотом» (URLSession, mock, інший сервер) — їй байдуже.
//  Завдяки цьому поведінку на помилки й порожню відповідь можна відтворити
//  без залежності від реального API (див. MockTodoService і тести).
//
//  Джерело даних: JSONPlaceholder — відкритий тестовий REST API, без авторизації.
//    Базова адреса: https://jsonplaceholder.typicode.com
//    Endpoint:      GET /todos
//    Параметри:     userId — задачі конкретного користувача (1…10),
//                   _limit — максимальна кількість елементів
//    Відповідь:     JSON-масив об'єктів { userId, id, title, completed }
//

import Foundation

protocol TodoService {
    func fetchTodos(userID: Int, limit: Int) async throws -> [RemoteTodo]
}

/// Реальна реалізація поверх `APIClient`.
struct RemoteTodoService: TodoService {
    let client: APIClient

    func fetchTodos(userID: Int, limit: Int) async throws -> [RemoteTodo] {
        let endpoint = Endpoint(
            path: "todos",
            queryItems: [
                URLQueryItem(name: "userId", value: String(userID)),
                URLQueryItem(name: "_limit", value: String(limit))
            ]
        )
        return try await client.get(endpoint, as: [RemoteTodo].self)
    }
}
