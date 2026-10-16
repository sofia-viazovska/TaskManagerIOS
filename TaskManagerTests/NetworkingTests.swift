//
//  NetworkingTests.swift
//  TaskManagerTests
//
//  Мережевий шар перевіряємо БЕЗ реальної мережі: замість URLSession у `APIClient`
//  підставляється `StubTransport`, який повертає заздалегідь задані байти чи помилку.
//  Так можна надійно відтворити будь-який збій (HTTP 500, обрив зв'язку, «зламаний» JSON),
//  не покладаючись на випадкову поведінку зовнішнього API.
//

import Foundation
import Testing
@testable import TaskManager

/// Транспорт-заглушка: повертає задану відповідь і запам'ятовує останній запит.
@MainActor
private final class StubTransport: HTTPTransport {
    enum Reply {
        case response(Data, URLResponse)
        case failure(any Error)
    }

    var reply: Reply
    private(set) var lastRequest: URLRequest?

    init(_ reply: Reply) {
        self.reply = reply
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        switch reply {
        case .response(let data, let response):
            return (data, response)
        case .failure(let error):
            throw error
        }
    }

    /// HTTP-відповідь із заданим статусом і тілом.
    static func http(status: Int, body: String) -> StubTransport {
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return StubTransport(.response(Data(body.utf8), response))
    }

    static func failing(_ error: any Error) -> StubTransport {
        StubTransport(.failure(error))
    }
}

@MainActor
struct NetworkingTests {
    private let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!

    private func makeClient(_ transport: StubTransport) -> APIClient {
        APIClient(baseURL: baseURL, transport: transport)
    }

    /// Виконує типовий запит і повертає мережеву помилку (або `nil`, якщо запит вдався).
    private func failure(of transport: StubTransport) async -> NetworkError? {
        do {
            _ = try await makeClient(transport).get(Endpoint(path: "todos"), as: [RemoteTodo].self)
            return nil
        } catch {
            return error as? NetworkError
        }
    }

    private let validJSON = """
    [
      {"userId": 1, "id": 1, "title": "delectus aut autem", "completed": false},
      {"userId": 1, "id": 2, "title": "quis ut nam facilis", "completed": true}
    ]
    """

    // MARK: Структура запиту (Endpoint)

    @Test func endpointBuildsURLWithQueryItemsAndDefaultHeaders() throws {
        let endpoint = Endpoint(
            path: "todos",
            queryItems: [URLQueryItem(name: "userId", value: "1"), URLQueryItem(name: "_limit", value: "20")]
        )

        let request = try endpoint.makeRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://jsonplaceholder.typicode.com/todos?userId=1&_limit=20")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.httpBody == nil)
        #expect(request.timeoutInterval == Endpoint.timeout)
    }

    @Test func endpointWithoutQueryItemsHasNoQuestionMark() throws {
        let request = try Endpoint(path: "todos").makeRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://jsonplaceholder.typicode.com/todos")
    }

    @Test func endpointSupportsMethodHeadersAndBody() throws {
        let body = Data("{\"title\":\"x\"}".utf8)
        let endpoint = Endpoint(
            path: "todos",
            method: .post,
            headers: ["Content-Type": "application/json", "Authorization": "Bearer token"],
            body: body
        )

        let request = try endpoint.makeRequest(baseURL: baseURL)

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.httpBody == body)
    }

    // MARK: Успіх і декодування

    @Test func successfulResponseIsDecodedIntoTypedModels() async throws {
        let transport = StubTransport.http(status: 200, body: validJSON)

        let todos = try await makeClient(transport).get(Endpoint(path: "todos"), as: [RemoteTodo].self)

        #expect(todos.count == 2)
        #expect(todos[0] == RemoteTodo(userID: 1, id: 1, title: "delectus aut autem", completed: false))
        #expect(todos[1].completed)
    }

    @Test func clientSendsRequestBuiltFromEndpoint() async throws {
        let transport = StubTransport.http(status: 200, body: "[]")
        let endpoint = Endpoint(path: "todos", queryItems: [URLQueryItem(name: "userId", value: "7")])

        _ = try await makeClient(transport).get(endpoint, as: [RemoteTodo].self)

        #expect(transport.lastRequest?.url?.absoluteString == "https://jsonplaceholder.typicode.com/todos?userId=7")
    }

    @Test func decodingMapsJSONKeyUserIdToUserID() throws {
        let json = Data(#"{"userId": 5, "id": 9, "title": "t", "completed": true}"#.utf8)

        let todo = try JSONDecoder().decode(RemoteTodo.self, from: json)

        #expect(todo.userID == 5)
        #expect(todo.id == 9)
    }

    // MARK: Помилки: HTTP-статус

    @Test func notFoundStatusIsHTTPError() async {
        let error = await failure(of: .http(status: 404, body: "{}"))

        #expect(error == .httpStatus(404))
        #expect(error?.category == .http)
    }

    @Test func serverErrorStatusIsCheckedBeforeDecoding() async {
        // Тіло — ВАЛІДНИЙ JSON, який декодувався б успішно. Але статус 500 — це помилка:
        // дані з відповіді з помилкою не можна вважати результатом.
        let error = await failure(of: .http(status: 500, body: validJSON))

        #expect(error == .httpStatus(500))
    }

    @Test func redirectStatusIsNotTreatedAsSuccess() async {
        let error = await failure(of: .http(status: 304, body: ""))

        #expect(error == .httpStatus(304))
    }

    // MARK: Помилки: декодування

    @Test func malformedJSONIsDecodingError() async {
        let error = await failure(of: .http(status: 200, body: "це не JSON"))

        #expect(error?.category == .decoding)
    }

    @Test func wrongShapeIsDecodingError() async {
        // Очікуємо масив, а сервер повернув об'єкт.
        let error = await failure(of: .http(status: 200, body: #"{"id": 1}"#))

        #expect(error?.category == .decoding)
    }

    @Test func missingKeyIsDecodingErrorNamingTheField() async {
        let body = #"[{"id": 1, "title": "x", "completed": false}]"#

        let error = await failure(of: .http(status: 200, body: body))

        #expect(error == .decoding("немає поля «userId»"))
    }

    @Test func wrongTypeIsDecodingError() async {
        let body = #"[{"userId": 1, "id": "один", "title": "x", "completed": false}]"#

        let error = await failure(of: .http(status: 200, body: body))

        #expect(error?.category == .decoding)
    }

    // MARK: Помилки: транспорт

    @Test func noInternetIsTransportError() async {
        let error = await failure(of: .failing(URLError(.notConnectedToInternet)))

        #expect(error == .transport(.notConnectedToInternet))
        #expect(error?.category == .transport)
    }

    @Test func timeoutIsTransportError() async {
        let error = await failure(of: .failing(URLError(.timedOut)))

        #expect(error == .transport(.timedOut))
    }

    @Test func urlSessionCancellationIsCancelledNotTransport() async {
        let error = await failure(of: .failing(URLError(.cancelled)))

        #expect(error == .cancelled)
    }

    @Test func structuredCancellationIsCancelled() async {
        let error = await failure(of: .failing(CancellationError()))

        #expect(error == .cancelled)
    }

    @Test func nonHTTPResponseIsInvalidResponse() async {
        let url = URL(string: "https://example.com")!
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        let transport = StubTransport(.response(Data(), response))

        let error = await failure(of: transport)

        #expect(error == .invalidResponse)
    }

    // MARK: Повідомлення для користувача

    @Test func userMessagesDistinguishErrorKinds() {
        let offline = NetworkError.transport(.notConnectedToInternet).userMessage
        let timeout = NetworkError.transport(.timedOut).userMessage
        let notFound = NetworkError.httpStatus(404).userMessage
        let server = NetworkError.httpStatus(503).userMessage
        let decoding = NetworkError.decoding("деталі").userMessage

        #expect(offline.contains("інтернет"))
        #expect(timeout.contains("вчасно"))
        #expect(notFound.contains("404"))
        #expect(server.contains("503"))
        #expect(decoding.contains("форматі"))
        #expect(Set([offline, timeout, notFound, server, decoding]).count == 5)
    }

    @Test func userMessageDoesNotLeakTechnicalDecodingDetails() {
        let message = NetworkError.decoding("немає поля «userId»").userMessage

        #expect(!message.contains("userId"))
    }

    @Test func localizedDescriptionEqualsUserMessage() {
        let error = NetworkError.httpStatus(500)

        #expect(error.localizedDescription == error.userMessage)
    }

    @Test func categoriesAndRetryability() {
        #expect(NetworkError.transport(.timedOut).category == .transport)
        #expect(NetworkError.httpStatus(500).category == .http)
        #expect(NetworkError.decoding("x").category == .decoding)
        #expect(NetworkError.cancelled.category == .other)
        #expect(NetworkError.invalidURL.isRetryable == false)
        #expect(NetworkError.httpStatus(500).isRetryable)
    }

    // MARK: TodoService

    @Test func remoteServiceRequestsTodosOfUserWithLimit() async throws {
        let transport = StubTransport.http(status: 200, body: validJSON)
        let service = RemoteTodoService(client: makeClient(transport))

        let todos = try await service.fetchTodos(userID: 3, limit: 5)

        let url = try #require(transport.lastRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.path == "/todos")
        #expect(items.contains(URLQueryItem(name: "userId", value: "3")))
        #expect(items.contains(URLQueryItem(name: "_limit", value: "5")))
        #expect(todos.count == 2)
    }

    @Test func remoteServicePropagatesNetworkError() async {
        let service = RemoteTodoService(client: makeClient(.http(status: 500, body: "")))

        do {
            _ = try await service.fetchTodos(userID: 1, limit: 20)
            Issue.record("Очікувалась помилка")
        } catch {
            #expect(error as? NetworkError == .httpStatus(500))
        }
    }

    // MARK: Вибір сервісу за аргументами запуску

    @Test func launchArgumentsSelectMockScenarios() async throws {
        let empty = AppEnvironment.makeTodoService(arguments: ["-network-empty"])
        let broken = AppEnvironment.makeTodoService(arguments: ["-network-error"])
        let offline = AppEnvironment.makeTodoService(arguments: ["-network-offline"])
        let decoding = AppEnvironment.makeTodoService(arguments: ["-network-decoding"])

        #expect(try await empty.fetchTodos(userID: 1, limit: 20).isEmpty)
        await expectFailure(of: broken, equals: .httpStatus(500))
        await expectFailure(of: offline, equals: .transport(.notConnectedToInternet))
        await expectFailure(of: decoding, equals: .decoding("немає поля «title»"))
    }

    @Test func flakyArgumentFailsOnceThenSucceeds() async throws {
        let service = AppEnvironment.makeTodoService(arguments: ["-network-flaky"])

        await expectFailure(of: service, equals: .httpStatus(503))
        let todos = try await service.fetchTodos(userID: 1, limit: 20)

        #expect(todos == RemoteTodo.samples)
    }

    @Test func noArgumentsSelectsRealService() {
        let service = AppEnvironment.makeTodoService(arguments: [])

        #expect(service is RemoteTodoService)
    }

    private func expectFailure(of service: any TodoService, equals expected: NetworkError) async {
        do {
            _ = try await service.fetchTodos(userID: 1, limit: 20)
            Issue.record("Очікувалась помилка \(expected)")
        } catch {
            #expect(error as? NetworkError == expected)
        }
    }
}
