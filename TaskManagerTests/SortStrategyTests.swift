//
//  SortStrategyTests.swift
//  TaskManagerTests
//
//  Перевіряє патерн Strategy: кожна стратегія окремо, без ViewModel і UI.
//

import Foundation
import Testing
@testable import TaskManager

@MainActor
struct SortStrategyTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        base.addingTimeInterval(TimeInterval(offset) * 24 * 60 * 60)
    }

    @Test func prioritySortPutsHighFirstAndBreaksTiesByTitle() {
        let tasks = [
            TaskItem(title: "B", priority: .low),
            TaskItem(title: "C", priority: .high),
            TaskItem(title: "A", priority: .high),
            TaskItem(title: "D", priority: .medium)
        ]

        let result = PrioritySortStrategy().sorted(tasks).map(\.title)

        #expect(result == ["A", "C", "D", "B"])
    }

    @Test func dueDateSortPutsNearestFirstAndMissingDatesLast() {
        let tasks = [
            TaskItem(title: "Без дати"),
            TaskItem(title: "Пізно", dueDate: day(5)),
            TaskItem(title: "Скоро", dueDate: day(1))
        ]

        let result = DueDateSortStrategy().sorted(tasks).map(\.title)

        #expect(result == ["Скоро", "Пізно", "Без дати"])
    }

    @Test func titleSortIsAlphabetical() {
        let tasks = [
            TaskItem(title: "Борщ"),
            TaskItem(title: "Аптека"),
            TaskItem(title: "Вода")
        ]

        let result = TitleSortStrategy().sorted(tasks).map(\.title)

        #expect(result == ["Аптека", "Борщ", "Вода"])
    }

    @Test func sortOptionMapsToMatchingStrategy() {
        #expect(SortOption.priority.strategy.name == PrioritySortStrategy().name)
        #expect(SortOption.dueDate.strategy.name == DueDateSortStrategy().name)
        #expect(SortOption.title.strategy.name == TitleSortStrategy().name)
    }
}
