//
//  TaskItemBuilderTests.swift
//  TaskManagerTests
//
//  Перевіряє патерн Builder: валідацію та поведінку без жодного UI.
//

import Foundation
import Testing
@testable import TaskManager

@MainActor
struct TaskItemBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func buildsTaskWithDefaultsAndTrimmedTitle() throws {
        let task = try TaskItemBuilder(title: "  Купити молоко  ").build()

        #expect(task.title == "Купити молоко")
        #expect(task.priority == .medium)
        #expect(task.dueDate == nil)
        #expect(task.isDone == false)
    }

    @Test func rejectsEmptyTitle() {
        #expect(throws: TaskItemBuilderError.emptyTitle) {
            try TaskItemBuilder(title: "   ").build()
        }
    }

    @Test func rejectsTooLongTitle() {
        let longTitle = String(repeating: "a", count: TaskItemBuilder.maxTitleLength + 1)

        #expect(throws: TaskItemBuilderError.titleTooLong(limit: TaskItemBuilder.maxTitleLength)) {
            try TaskItemBuilder(title: longTitle).build()
        }
    }

    @Test func dueDateIsCalculatedFromInjectedClock() throws {
        let task = try TaskItemBuilder(title: "Дедлайн")
            .dueIn(days: 2, from: now)
            .build()

        #expect(task.dueDate == now.addingTimeInterval(2 * 24 * 60 * 60))
    }

    @Test func builderIsValueTypeSoTemplatesCanBranch() throws {
        let template = TaskItemBuilder(title: "Шаблон")

        let high = try template.withPriority(.high).build()
        let plain = try template.build()

        #expect(high.priority == .high)
        #expect(plain.priority == .medium)
    }

    @Test func notesAreTrimmedAndStored() throws {
        let task = try TaskItemBuilder(title: "З нотатками")
            .withNotes("  деталі  \n")
            .build()

        #expect(task.notes == "деталі")
    }

    @Test func withIDKeepsIdentifierForEditing() throws {
        let id = UUID()

        let task = try TaskItemBuilder(title: "Редагована").withID(id).build()
        let other = try TaskItemBuilder(title: "Нова").build()

        #expect(task.id == id)
        #expect(other.id != id)
    }

    @Test func overdueOnlyForPendingTasksWithPastDeadline() throws {
        let past = try TaskItemBuilder(title: "Минуле").dueIn(days: -1, from: now).build()
        let future = try TaskItemBuilder(title: "Майбутнє").dueIn(days: 1, from: now).build()
        let doneInPast = try TaskItemBuilder(title: "Готова").dueIn(days: -1, from: now).markedDone().build()
        let noDeadline = try TaskItemBuilder(title: "Без дедлайну").build()

        #expect(past.isOverdue(at: now))
        #expect(!future.isOverdue(at: now))
        #expect(!doneInPast.isOverdue(at: now))
        #expect(!noDeadline.isOverdue(at: now))
    }
}
