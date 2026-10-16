//
//  ServerTasksViewModelTests.swift
//  TaskManagerTests
//
//  Стани екрана імпорту перевіряємо з керованим `MockTodoService`:
//  жодних реальних запитів, а порожня відповідь і помилки відтворюються точно й щоразу однаково.
//

import Foundation
import Testing
@testable import TaskManager

@MainActor
struct ServerTasksViewModelTests {
    private func makeViewModel(
        _ script: [MockTodoService.Outcome],
        delay: Duration = .zero
    ) -> (ServerTasksViewModel, MockTodoService) {
        let service = MockTodoService(script: script, delay: delay)
        return (ServerTasksViewModel(service: service), service)
    }

    // MARK: Стани

    @Test func startsIdle() {
        let (viewModel, service) = makeViewModel([.todos([])])

        #expect(viewModel.state == .idle)
        #expect(service.callCount == 0)
    }

    @Test func successLoadsTodos() async {
        let (viewModel, service) = makeViewModel([.todos(RemoteTodo.samples)])

        await viewModel.load()

        #expect(viewModel.state == .loaded(RemoteTodo.samples))
        #expect(service.callCount == 1)
    }

    @Test func emptyResponseGivesEmptyState() async {
        let (viewModel, _) = makeViewModel([.todos([])])

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test func httpErrorGivesFailedState() async {
        let (viewModel, _) = makeViewModel([.failure(.httpStatus(500))])

        await viewModel.load()

        #expect(viewModel.state == .failed(.httpStatus(500)))
    }

    @Test func transportErrorGivesFailedState() async {
        let (viewModel, _) = makeViewModel([.failure(.transport(.notConnectedToInternet))])

        await viewModel.load()

        #expect(viewModel.state == .failed(.transport(.notConnectedToInternet)))
    }

    @Test func decodingErrorGivesFailedState() async {
        let (viewModel, _) = makeViewModel([.failure(.decoding("немає поля «title»"))])

        await viewModel.load()

        guard case .failed(let error) = viewModel.state else {
            Issue.record("Очікувався стан failed, а не \(viewModel.state)")
            return
        }
        #expect(error.category == .decoding)
    }

    @Test func unexpectedErrorIsWrappedAsUnknown() async {
        struct Strange: Error {}
        let service = ThrowingService(error: Strange())
        let viewModel = ServerTasksViewModel(service: service)

        await viewModel.load()

        guard case .failed(.unknown) = viewModel.state else {
            Issue.record("Очікувався failed(.unknown), а не \(viewModel.state)")
            return
        }
    }

    // MARK: Повторення

    @Test func retryAfterFailureLoadsData() async {
        // Сценарій: перший запит — збій 503, другий — успіх. Це кнопка «Повторити».
        let (viewModel, service) = makeViewModel([.failure(.httpStatus(503)), .todos(RemoteTodo.samples)])

        await viewModel.load()
        #expect(viewModel.state == .failed(.httpStatus(503)))

        await viewModel.load()
        #expect(viewModel.state == .loaded(RemoteTodo.samples))
        #expect(service.callCount == 2)
    }

    @Test func successAfterSuccessReplacesDataAndLastOutcomeRepeats() async {
        let (viewModel, service) = makeViewModel([.todos(RemoteTodo.samples)])

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.state == .loaded(RemoteTodo.samples))
        #expect(service.callCount == 2)
    }

    // MARK: Параметри запиту

    @Test func requestUsesSelectedUserAndPageLimit() async {
        let service = MockTodoService(script: [.todos([])])
        let viewModel = ServerTasksViewModel(service: service, pageLimit: 3)
        viewModel.userID = 4

        await viewModel.load()

        #expect(service.requests.count == 1)
        #expect(service.requests.first?.userID == 4)
        #expect(service.requests.first?.limit == 3)
    }

    @Test func defaultRequestIsUserOneWithTwentyItems() async {
        let (viewModel, service) = makeViewModel([.todos([])])

        await viewModel.load()

        #expect(service.requests.first?.userID == 1)
        #expect(service.requests.first?.limit == 20)
    }

    // MARK: Завантаження й скасування (UI не блокується)

    @Test func stateIsLoadingWhileRequestIsInFlight() async {
        let (viewModel, _) = makeViewModel([.todos(RemoteTodo.samples)], delay: .seconds(5))

        let task = Task { await viewModel.load() }
        // Віддаємо виконання: `load()` доходить до `await` (очікування відповіді) й призупиняється.
        // Якби виклик блокував потік, тест не міг би продовжитися й побачити стан.
        await Task.yield()
        #expect(viewModel.state == .loading)

        task.cancel()
        await task.value
    }

    @Test func cancelledRequestDoesNotProduceErrorState() async {
        let (viewModel, _) = makeViewModel([.todos(RemoteTodo.samples)], delay: .seconds(5))

        let task = Task { await viewModel.load() }
        await Task.yield()
        task.cancel()
        await task.value

        // Скасування (закрили екран, змінили користувача) — не помилка й не «вічне завантаження».
        #expect(viewModel.state == .idle)
    }

    @Test func cancelledNetworkErrorIsNotShownAsFailure() async {
        let (viewModel, _) = makeViewModel([.failure(.cancelled)])

        await viewModel.load()

        #expect(viewModel.state == .idle)
    }

    // MARK: MockTodoService

    @Test func mockConsumesScriptInOrderAndRepeatsLastOutcome() async throws {
        let service = MockTodoService(script: [.todos([]), .todos(RemoteTodo.samples)])

        let first = try await service.fetchTodos(userID: 1, limit: 20)
        let second = try await service.fetchTodos(userID: 1, limit: 20)
        let third = try await service.fetchTodos(userID: 1, limit: 20)

        #expect(first.isEmpty)
        #expect(second == RemoteTodo.samples)
        #expect(third == RemoteTodo.samples)
        #expect(service.callCount == 3)
    }
}

/// Сервіс, що кидає довільну (не мережеву) помилку.
private struct ThrowingService: TodoService {
    let error: any Error

    func fetchTodos(userID: Int, limit: Int) async throws -> [RemoteTodo] {
        throw error
    }
}
