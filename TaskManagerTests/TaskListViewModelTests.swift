//
//  TaskListViewModelTests.swift
//  TaskManagerTests
//
//  Бізнес-логіку екрана перевіряємо без UI і без реального сховища:
//  ViewModel отримує InMemoryTaskRepository та фіксований годинник.
//

import Foundation
import Testing
@testable import TaskManager

/// Підроблене сховище, що завжди падає, — перевіряємо обробку помилок.
private struct FailingRepository: TaskRepository {
    nonisolated struct Failure: Error {}

    func loadTasks() throws -> [TaskItem] { throw Failure() }
    func saveTasks(_ tasks: [TaskItem]) throws { throw Failure() }
}

@MainActor
struct TaskListViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeViewModel(
        repository: any TaskRepository = InMemoryTaskRepository()
    ) -> TaskListViewModel {
        let clock = now
        return TaskListViewModel(listName: "Тест", repository: repository, now: { clock })
    }

    @Test func addTaskPublishesStateAndSavesToRepository() {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.addTask(title: "Нова", priority: .high)

        #expect(viewModel.tasks.map(\.title) == ["Нова"])
        #expect(repository.storedTasks.map(\.title) == ["Нова"])
        #expect(repository.saveCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func emptyTitleShowsErrorAndSavesNothing() {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.addTask(title: "   ", priority: .medium)

        #expect(viewModel.tasks.isEmpty)
        #expect(repository.saveCount == 0)
        #expect(viewModel.errorMessage == "Назва задачі не може бути порожньою")
    }

    @Test func deadlineIsComputedFromInjectedClock() {
        let viewModel = makeViewModel()

        viewModel.addTask(title: "З дедлайном", priority: .medium, dueInDays: 3)

        #expect(viewModel.tasks.first?.dueDate == now.addingTimeInterval(3 * 24 * 60 * 60))
    }

    @Test func loadShowsStoredTasksSortedByPriority() {
        let repository = InMemoryTaskRepository(initialTasks: [
            TaskItem(title: "Низька", priority: .low),
            TaskItem(title: "Висока", priority: .high)
        ])
        let viewModel = makeViewModel(repository: repository)

        viewModel.load()

        #expect(viewModel.tasks.map(\.title) == ["Висока", "Низька"])
    }

    @Test func toggleDoneUpdatesStateAndPersists() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.addTask(title: "Зробити", priority: .medium)
        let id = try #require(viewModel.tasks.first?.id)

        viewModel.toggleDone(id: id)

        #expect(viewModel.tasks.first?.isDone == true)
        #expect(repository.storedTasks.first?.isDone == true)
    }

    @Test func showOnlyPendingHidesCompletedTasks() throws {
        let viewModel = makeViewModel()
        viewModel.addTask(title: "Готова", priority: .low)
        viewModel.addTask(title: "В роботі", priority: .high)
        let doneID = try #require(viewModel.tasks.first { $0.title == "Готова" }?.id)
        viewModel.toggleDone(id: doneID)

        viewModel.showOnlyPending = true

        #expect(viewModel.tasks.map(\.title) == ["В роботі"])
    }

    @Test func changingSortOptionReordersWithoutTouchingRepository() {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.addTask(title: "Б", priority: .high)
        viewModel.addTask(title: "А", priority: .low)
        let savesBefore = repository.saveCount

        viewModel.sortOption = .title

        #expect(viewModel.tasks.map(\.title) == ["А", "Б"])
        #expect(repository.saveCount == savesBefore)
    }

    @Test func saveFailureIsShownToUser() {
        let viewModel = makeViewModel(repository: FailingRepository())

        viewModel.addTask(title: "Не збережеться", priority: .medium)

        #expect(viewModel.errorMessage?.contains("зберегти") == true)
    }

    @Test func loadFailureIsShownToUser() {
        let viewModel = makeViewModel(repository: FailingRepository())

        viewModel.load()

        #expect(viewModel.errorMessage?.contains("завантажити") == true)
    }
}
