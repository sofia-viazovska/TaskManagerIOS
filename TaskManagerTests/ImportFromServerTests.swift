//
//  ImportFromServerTests.swift
//  TaskManagerTests
//
//  Імпорт серверної задачі в локальний список: мапінг DTO → чернетка,
//  стан «виконано», захист від дублікатів.
//

import Foundation
import Testing
@testable import TaskManager

@MainActor
struct ImportFromServerTests {
    private func makeViewModel(repository: InMemoryTaskRepository = InMemoryTaskRepository()) -> TaskListViewModel {
        let clock = Date(timeIntervalSince1970: 1_700_000_000)
        return TaskListViewModel(listName: "Тест", repository: repository, now: { clock })
    }

    // MARK: DTO → чернетка

    @Test func draftCopiesTitleAndMarksSource() {
        let todo = RemoteTodo(userID: 1, id: 7, title: "  delectus aut autem  ", completed: false)

        let draft = todo.makeDraft()

        #expect(draft.title == "delectus aut autem")
        #expect(draft.priority == .medium)
        #expect(draft.dueDate == nil)
        #expect(draft.notes.contains("JSONPlaceholder"))
        #expect(draft.notes.contains("7"))
    }

    @Test func draftTruncatesTooLongTitleToBuilderLimit() throws {
        let longTitle = String(repeating: "а", count: 150)
        let todo = RemoteTodo(userID: 1, id: 1, title: longTitle, completed: false)

        let draft = todo.makeDraft()
        let viewModel = makeViewModel()

        #expect(draft.title.count == TaskItemBuilder.maxTitleLength)
        // Обрізана чернетка проходить валідацію Builder — імпорт не падає на довгих назвах.
        try viewModel.create(draft)
        #expect(viewModel.tasks.count == 1)
    }

    // MARK: create(isDone:)

    @Test func createReturnsIdOfNewTask() throws {
        let viewModel = makeViewModel()

        let id = try viewModel.create(TaskDraft(title: "Нова"))

        #expect(viewModel.task(id: id)?.title == "Нова")
    }

    @Test func createIsNotDoneByDefault() throws {
        let viewModel = makeViewModel()

        try viewModel.create(TaskDraft(title: "Нова"))

        #expect(viewModel.tasks.first?.isDone == false)
    }

    @Test func importedCompletedTodoIsCreatedAsDone() throws {
        let viewModel = makeViewModel()
        let todo = RemoteTodo(userID: 1, id: 4, title: "et porro tempora", completed: true)

        try viewModel.create(todo.makeDraft(), isDone: todo.completed)

        #expect(viewModel.tasks.first?.title == "et porro tempora")
        #expect(viewModel.tasks.first?.isDone == true)
    }

    @Test func importedTodoIsSavedToRepository() throws {
        let repository = InMemoryTaskRepository()
        let viewModel = makeViewModel(repository: repository)
        let todo = RemoteTodo(userID: 1, id: 1, title: "delectus aut autem", completed: false)

        try viewModel.create(todo.makeDraft(), isDone: todo.completed)

        #expect(repository.storedTasks.map(\.title) == ["delectus aut autem"])
    }

    @Test func importOfBlankServerTitleFailsValidation() {
        let viewModel = makeViewModel()
        let todo = RemoteTodo(userID: 1, id: 2, title: "   ", completed: false)

        #expect(throws: TaskItemBuilderError.emptyTitle) {
            try viewModel.create(todo.makeDraft())
        }
        #expect(viewModel.tasks.isEmpty)
    }

    // MARK: hasTask(titled:)

    @Test func hasTaskIgnoresCaseAndSurroundingSpaces() throws {
        let viewModel = makeViewModel()
        try viewModel.create(TaskDraft(title: "Delectus Aut Autem"))

        #expect(viewModel.hasTask(titled: "delectus aut autem"))
        #expect(viewModel.hasTask(titled: "  DELECTUS AUT AUTEM "))
        #expect(!viewModel.hasTask(titled: "інша задача"))
    }

    @Test func hasTaskSeesDoneTasksEvenWhenListShowsOnlyPending() throws {
        let viewModel = makeViewModel()
        let id = try viewModel.create(TaskDraft(title: "Готова"))
        viewModel.toggleDone(id: id)
        viewModel.showOnlyPending = true

        #expect(viewModel.tasks.isEmpty)
        #expect(viewModel.hasTask(titled: "Готова"))
    }

    @Test func importedTodoIsReportedAsAlreadyAdded() throws {
        let viewModel = makeViewModel()
        let todo = RemoteTodo(userID: 1, id: 1, title: "delectus aut autem", completed: false)
        #expect(!viewModel.hasTask(titled: todo.makeDraft().title))

        try viewModel.create(todo.makeDraft())

        #expect(viewModel.hasTask(titled: todo.makeDraft().title))
    }
}
