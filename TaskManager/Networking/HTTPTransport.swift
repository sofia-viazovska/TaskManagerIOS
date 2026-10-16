//
//  HTTPTransport.swift
//  TaskManager
//
//  Найнижчий рівень: «відправити запит, отримати байти й метадані відповіді».
//  Протокол потрібен, щоб у тестах підставити заглушку замість реальної мережі,
//  а `URLSession` лишився єдиною реальною реалізацією.
//

import Foundation

protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // `await`: потік не блокується — поки йде запит, головний потік обслуговує інтерфейс.
        try await data(for: request)
    }
}
