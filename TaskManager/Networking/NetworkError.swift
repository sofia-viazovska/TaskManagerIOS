//
//  NetworkError.swift
//  TaskManager
//
//  Помилки мережевого шару. Три принципово різні групи (і різні повідомлення для користувача):
//  • транспортна помилка — запит взагалі не дійшов або відповідь не прийшла
//    (немає інтернету, таймаут, не знайдено хост): `.transport`;
//  • HTTP-помилка — сервер відповів, але зі статусом не 2xx (404, 500…): `.httpStatus`;
//  • помилка декодування — статус 2xx, але тіло не відповідає очікуваній моделі: `.decoding`.
//

import Foundation

nonisolated enum NetworkError: Error, Equatable, LocalizedError {
    /// Не вдалося скласти URL із шляху та параметрів.
    case invalidURL
    /// Транспортна помилка `URLSession` (код `URLError`).
    case transport(URLError.Code)
    /// Відповідь прийшла, але це не HTTP-відповідь.
    case invalidResponse
    /// Сервер повернув статус поза 200–299.
    case httpStatus(Int)
    /// Тіло відповіді не вдалося перетворити на модель (опис — для логів).
    case decoding(String)
    /// Запит скасовано (наприклад, користувач закрив екран або змінив параметр).
    case cancelled
    case unknown(String)

    /// Група помилки — зручно для тестів і для пояснення на захисті.
    enum Category: Equatable {
        case transport
        case http
        case decoding
        case other
    }

    var category: Category {
        switch self {
        case .transport:
            return .transport
        case .httpStatus:
            return .http
        case .decoding:
            return .decoding
        case .invalidURL, .invalidResponse, .cancelled, .unknown:
            return .other
        }
    }

    /// Повторити запит має сенс майже завжди; виняток — некоректна адреса (помилка в коді).
    var isRetryable: Bool {
        switch self {
        case .invalidURL:
            return false
        default:
            return true
        }
    }

    /// Зрозуміле користувачеві повідомлення: без кодів і технічних подробиць, що можна зробити.
    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Некоректна адреса запиту."
        case .transport(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "Немає з’єднання з інтернетом. Перевірте мережу й повторіть."
            case .timedOut:
                return "Сервер не відповів вчасно. Спробуйте ще раз."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Не вдалося підключитися до сервера."
            default:
                return "Помилка мережі. Спробуйте ще раз."
            }
        case .invalidResponse:
            return "Сервер надіслав некоректну відповідь."
        case .httpStatus(let status):
            switch status {
            case 404:
                return "Дані на сервері не знайдено (код 404)."
            case 400..<500:
                return "Сервер відхилив запит (код \(status))."
            case 500..<600:
                return "Сервер тимчасово недоступний (код \(status)). Спробуйте пізніше."
            default:
                return "Неочікувана відповідь сервера (код \(status))."
            }
        case .decoding:
            return "Сервер повернув дані в неочікуваному форматі."
        case .cancelled:
            return "Запит скасовано."
        case .unknown(let message):
            return "Невідома помилка: \(message)"
        }
    }

    var errorDescription: String? { userMessage }
}
