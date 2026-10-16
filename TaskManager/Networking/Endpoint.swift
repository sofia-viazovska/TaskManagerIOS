//
//  Endpoint.swift
//  TaskManager
//
//  Опис HTTP-запиту як даних: метод, шлях, параметри (query), заголовки й тіло.
//  З цих частин складається будь-який запит; `Endpoint` лише збирає їх у `URLRequest`.
//

import Foundation

nonisolated enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

nonisolated struct Endpoint: Equatable {
    /// Шлях відносно базової адреси, наприклад `todos`.
    var path: String
    /// Параметри рядка запиту: `?userId=1&_limit=20`.
    var queryItems: [URLQueryItem] = []
    /// Метод визначає намір: GET читає, POST створює, PUT/PATCH змінюють, DELETE видаляє.
    var method: HTTPMethod = .get
    /// Заголовки: метадані запиту (які дані приймаємо, тип тіла, авторизація).
    var headers: [String: String] = [:]
    /// Тіло — дані, що відправляються серверу (для GET відсутнє).
    var body: Data?

    /// Час очікування відповіді (секунди). Без нього запит міг би «висіти» дуже довго.
    static let timeout: TimeInterval = 15

    func makeRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }
        // Порожній queryItems дав би зайвий «?» в адресі.
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.httpMethod = method.rawValue
        // Просимо JSON; власні заголовки endpoint-а мають пріоритет.
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body
        return request
    }
}
