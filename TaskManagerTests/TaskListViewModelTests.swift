//
//  TaskListViewModelTests.swift
//  TaskManagerTests
//
//  Бізнес-логіку екранів перевіряємо без UI і без реального сховища:
//  ViewModel отримує InMemoryTaskRepository та фіксований годинник.
//  Лаба 3: створення, редагування за id, видалення, чернетка, статистика.
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
    private let day: TimeInterval = 24 * 60 * 60

    private func makeViewModel(
        repository: any TaskRepository = InMemoryTaskRepository()
    ) -> TaskListViewModel {
        let clock = now
        return TaskListViewModel(listName: "Тест", repository: repository, now: { clock })
    }

    // MARK: Створення

    @Test func createPublishesStateAndSavesToRepository() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)

        try viewModel.create(TaskDraft(title: "Нова", priority: .high, notes: "Деталі"))

        #expect(viewModel.tasks.map(\.title) == ["Нова"])
        #expect(viewModel.tasks.first?.notes == "Деталі")
        #expect(repository.storedTasks.map(\.title) == ["Нова"])
        #expect(repository.saveCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func createWithEmptyTitleThrowsAndSavesNothing() {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)

        #expect(throws: TaskItemBuilderError.emptyTitle) {
            try viewModel.create(TaskDraft(title: "   "))
        }

        #expect(viewModel.tasks.isEmpty)
        #expect(repository.saveCount == 0)
    }

    @Test func defaultDeadlineIsTomorrowAccordingToInjectedClock() {
        let viewModel = makeViewModel()

        #expect(viewModel.defaultDeadline == now.addingTimeInterval(day))
    }

    // MARK: Редагування

    @Test func updateChangesFieldsButKeepsIdentityAndDoneState() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        try viewModel.create(TaskDraft(title: "Стара назва", priority: .low))
        let id = try #require(viewModel.tasks.first?.id)
        viewModel.toggleDone(id: id)

        try viewModel.update(
            id: id,
            with: TaskDraft(title: "Нова назва", priority: .high, dueDate: now, notes: "Нотатки")
        )

        let updated = try #require(viewModel.task(id: id))
        #expect(viewModel.tasks.count == 1)
        #expect(updated.id == id)
        #expect(updated.title == "Нова назва")
        #expect(updated.priority == .high)
        #expect(updated.dueDate == now)
        #expect(updated.notes == "Нотатки")
        #expect(updated.isDone == true)
        #expect(repository.storedTasks.first?.title == "Нова назва")
    }

    @Test func updateWithInvalidDraftLeavesTaskUntouched() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        try viewModel.create(TaskDraft(title: "Лишається"))
        let id = try #require(viewModel.tasks.first?.id)
        let savesBefore = repository.saveCount

        #expect(throws: TaskItemBuilderError.emptyTitle) {
            try viewModel.update(id: id, with: TaskDraft(title: ""))
        }

        #expect(viewModel.task(id: id)?.title == "Лишається")
        #expect(repository.saveCount == savesBefore)
    }

    @Test func updateOfMissingTaskThrowsTaskNotFound() {
        let viewModel = makeViewModel()

        #expect(throws: TaskEditingError.taskNotFound) {
            try viewModel.update(id: UUID(), with: TaskDraft(title: "Нічого оновлювати"))
        }
    }

    @Test func draftReflectsStoredTaskAndIsNilForMissing() throws {
        let viewModel = makeViewModel()
        try viewModel.create(TaskDraft(title: "Задача", priority: .high, dueDate: now, notes: "Нотатки"))
        let id = try #require(viewModel.tasks.first?.id)

        let draft = viewModel.draft(for: id)

        #expect(draft == TaskDraft(title: "Задача", priority: .high, dueDate: now, notes: "Нотатки"))
        #expect(viewModel.draft(for: UUID()) == nil)
    }

    // MARK: Видалення

    @Test func deleteRemovesTaskAndPersists() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        try viewModel.create(TaskDraft(title: "Залишити"))
        try viewModel.create(TaskDraft(title: "Видалити"))
        let id = try #require(viewModel.tasks.first { $0.title == "Видалити" }?.id)

        viewModel.delete(id: id)

        #expect(viewModel.tasks.map(\.title) == ["Залишити"])
        #expect(viewModel.task(id: id) == nil)
        #expect(repository.storedTasks.map(\.title) == ["Залишити"])
    }

    @Test func deleteOfMissingTaskDoesNothing() {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.delete(id: UUID())

        #expect(repository.saveCount == 0)
    }

    // MARK: Завантаження, статус, вигляд

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
        try viewModel.create(TaskDraft(title: "Зробити"))
        let id = try #require(viewModel.tasks.first?.id)

        viewModel.toggleDone(id: id)

        #expect(viewModel.tasks.first?.isDone == true)
        #expect(repository.storedTasks.first?.isDone == true)
    }

    @Test func showOnlyPendingHidesCompletedTasks() throws {
        let viewModel = makeViewModel()
        try viewModel.create(TaskDraft(title: "Готова", priority: .low))
        try viewModel.create(TaskDraft(title: "В роботі", priority: .high))
        let doneID = try #require(viewModel.tasks.first { $0.title == "Готова" }?.id)
        viewModel.toggleDone(id: doneID)

        viewModel.showOnlyPending = true

        #expect(viewModel.tasks.map(\.title) == ["В роботі"])
    }

    @Test func changingSortOptionReordersWithoutTouchingRepository() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        try viewModel.create(TaskDraft(title: "Б", priority: .high))
        try viewModel.create(TaskDraft(title: "А", priority: .low))
        let savesBefore = repository.saveCount

        viewModel.sortOption = .title

        #expect(viewModel.tasks.map(\.title) == ["А", "Б"])
        #expect(repository.saveCount == savesBefore)
    }

    // MARK: Статистика

    @Test func statisticsCountsDoneOverdueAndPriorities() throws {
        let viewModel = makeViewModel()
        try viewModel.create(TaskDraft(title: "Прострочена", priority: .high, dueDate: now.addingTimeInterval(-day)))
        try viewModel.create(TaskDraft(title: "Майбутня", priority: .high, dueDate: now.addingTimeInterval(day)))
        try viewModel.create(TaskDraft(title: "Готова", priority: .low, dueDate: now.addingTimeInterval(-day)))
        let doneID = try #require(viewModel.tasks.first { $0.title == "Готова" }?.id)
        viewModel.toggleDone(id: doneID)

        let stats = viewModel.statistics

        #expect(stats.total == 3)
        #expect(stats.completed == 1)
        #expect(stats.pending == 2)
        #expect(stats.overdue == 1)
        #expect(stats.count(for: .high) == 2)
        #expect(stats.count(for: .low) == 1)
        #expect(stats.count(for: .medium) == 0)
        #expect(abs(stats.completionRatio - 1.0 / 3.0) < 0.0001)
    }

    @Test func statisticsOfEmptyListHasZeroRatio() {
        let stats = makeViewModel().statistics

        #expect(stats.total == 0)
        #expect(stats.completionRatio == 0)
    }

    // MARK: Помилки сховища

    @Test func saveFailureIsShownToUser() throws {
        let viewModel = makeViewModel(repository: FailingRepository())

        try viewModel.create(TaskDraft(title: "Не збережеться"))

        #expect(viewModel.errorMessage?.contains("зберегти") == true)
    }

    @Test func loadFailureIsShownToUser() {
        let viewModel = makeViewModel(repository: FailingRepository())

        viewModel.load()

        #expect(viewModel.errorMessage?.contains("завантажити") == true)
    }
}
