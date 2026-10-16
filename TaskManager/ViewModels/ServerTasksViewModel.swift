//
//  ServerTasksViewModel.swift
//  TaskManager
//
//  Стан екрана «Імпорт із сервера». Єдине джерело правди для UI: екран лише малює `state`
//  і викликає `load()`. Про URLSession, JSON і HTTP ViewModel нічого не знає —
//  працює через протокол `TodoService`, який передається ззовні (DI в init).
//

import Combine
import Foundation

/// Усі стани екрана. Одночасно можливий рівно один — некоректні комбінації
/// (наприклад, «завантаження + помилка») неможливо уявити.
enum ImportState: Equatable {
    /// Запит ще не відправлявся.
    case idle
    /// Запит у процесі.
    case loading
    /// Успіх: є дані.
    case loaded([RemoteTodo])
    /// Успіх, але сервер повернув порожній список.
    case empty
    /// Помилка (з типом, щоб показати доречне повідомлення).
    case failed(NetworkError)
}

final class ServerTasksViewModel: ObservableObject {
    @Published private(set) var state: ImportState = .idle
    /// Чия колекція задач запитується (JSONPlaceholder має користувачів 1…10).
    @Published var userID: Int = 1

    static let userIDRange = 1...10
    let pageLimit: Int

    private let service: any TodoService

    init(service: any TodoService, pageLimit: Int = 20) {
        self.service = service
        self.pageLimit = pageLimit
    }

    /// Завантажує задачі. `async`: виклик не блокує головний потік — на час очікування
    /// відповіді функція призупиняється (`await`), а інтерфейс залишається живим.
    /// Оскільки ViewModel працює на головному акторі, оновлення `state` одразу відбуваються
    /// на main — окремий `DispatchQueue.main.async` не потрібен.
    func load() async {
        state = .loading
        do {
            let todos = try await service.fetchTodos(userID: userID, limit: pageLimit)
            // Якщо поки чекали, запит скасували (закрили екран, змінили користувача) —
            // не перезаписуємо стан застарілою відповіддю.
            try Task.checkCancellation()
            state = todos.isEmpty ? .empty : .loaded(todos)
        } catch is CancellationError {
            resetIfLoading()
        } catch let error as NetworkError {
            if error == .cancelled {
                resetIfLoading()
            } else {
                state = .failed(error)
            }
        } catch {
            state = .failed(.unknown(error.localizedDescription))
        }
    }

    /// Скасування — не помилка для користувача: нічого не показуємо, а стан «Завантаження»
    /// не залишаємо назавжди. Якщо тим часом уже стартував новий запит, він сам виставить стан.
    private func resetIfLoading() {
        if state == .loading {
            state = .idle
        }
    }
}
