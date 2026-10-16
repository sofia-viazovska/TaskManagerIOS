//
//  APIClient.swift
//  TaskManager
//
//  Єдиний компонент, що виконує запити й перетворює відповіді на типізовані значення.
//  Порядок обробки відповіді фіксований:
//    1. відправити запит — інакше транспортна помилка;
//    2. переконатися, що це HTTP-відповідь;
//    3. перевірити статус 2xx — ДО того, як торкатися тіла (тіло помилки — не наші дані);
//    4. декодувати JSON у модель — інакше помилка декодування.
//

import Foundation

struct APIClient {
    let baseURL: URL
    let transport: any HTTPTransport

    func get<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let request = try endpoint.makeRequest(baseURL: baseURL)

        // 1. Транспорт
        let result: (Data, URLResponse)
        do {
            result = try await transport.send(request)
        } catch let error as URLError {
            throw error.code == .cancelled ? NetworkError.cancelled : NetworkError.transport(error.code)
        } catch is CancellationError {
            throw NetworkError.cancelled
        } catch {
            // Будь-що інше теж оформлюємо як `NetworkError`: ззовні — єдиний тип помилок.
            throw NetworkError.unknown(error.localizedDescription)
        }
        let (data, response) = result

        // 2–3. Це HTTP-відповідь зі статусом 2xx?
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        log(request, status: http.statusCode, bytes: data.count)
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpStatus(http.statusCode)
        }

        // 4. Декодування
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(Self.describe(error))
        }
    }

    // MARK: Допоміжне

    /// Короткий опис помилки декодування (для логів, не для користувача).
    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decodingError {
        case .keyNotFound(let key, _):
            return "немає поля «\(key.stringValue)»"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "невідповідний тип або порожнє значення в «\(path)»"
        case .dataCorrupted:
            return "пошкоджений JSON"
        @unknown default:
            return "помилка декодування"
        }
    }

    /// Рядок у консолі Xcode — доказ реального запиту під час перевірки.
    private func log(_ request: URLRequest, status: Int, bytes: Int) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        print("[Network] \(method) \(url) -> \(status), \(bytes) bytes")
        #endif
    }
}
