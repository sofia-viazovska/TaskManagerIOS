//
//  RepositoryTests.swift
//  TaskManagerTests
//
//  Контрактні тести TaskRepository: ті самі перевірки для всіх реалізацій
//  (Liskov Substitution) + особливості адаптера UserDefaults.
//

import Foundation
import Testing
@testable import TaskManager

@MainActor
struct RepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Контракт: порожнє сховище дає [], а після save → load повертається те саме.
    private func verifyContract(of repository: any TaskRepository) throws {
        #expect(try repository.loadTasks().isEmpty)

        let tasks = [
            TaskItem(title: "Перша", priority: .high, dueDate: now, notes: "Нотатки до першої"),
            TaskItem(title: "Друга", priority: .low, isDone: true)
        ]
        try repository.saveTasks(tasks)
        let loaded = try repository.loadTasks()

        #expect(loaded.map(\.id) == tasks.map(\.id))
        #expect(loaded.map(\.title) == tasks.map(\.title))
        #expect(loaded.map(\.priority) == tasks.map(\.priority))
        #expect(loaded.map(\.dueDate) == tasks.map(\.dueDate))
        #expect(loaded.map(\.isDone) == tasks.map(\.isDone))
        #expect(loaded.map(\.notes) == tasks.map(\.notes))
    }

    private func makeIsolatedDefaults() throws -> (UserDefaults, String) {
        let suite = "TaskManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, suite)
    }

    @Test func inMemoryRepositoryHonoursContract() throws {
        try verifyContract(of: InMemoryTaskRepository())
    }

    @Test func userDefaultsRepositoryHonoursContract() throws {
        let (defaults, suite) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        try verifyContract(of: UserDefaultsTaskRepository(defaults: defaults, key: "tasks"))
    }

    @Test func corruptedDataIsReportedAsError() throws {
        let (defaults, suite) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("це не JSON".utf8), forKey: "tasks")
        let repository = UserDefaultsTaskRepository(defaults: defaults, key: "tasks")

        #expect(throws: (any Error).self) {
            try repository.loadTasks()
        }
    }

    @Test func unknownPriorityFallsBackToMedium() throws {
        let (defaults, suite) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let record = TaskRecord(id: UUID(), title: "Стара задача", priority: "urgent", dueDate: nil, isDone: false)
        defaults.set(try JSONEncoder().encode([record]), forKey: "tasks")
        let repository = UserDefaultsTaskRepository(defaults: defaults, key: "tasks")

        let loaded = try repository.loadTasks()

        #expect(loaded.count == 1)
        #expect(loaded.first?.priority == .medium)
    }

    /// Дані, збережені лабою 2, не мають поля notes — вони мусять читатися без помилки.
    @Test func recordsSavedWithoutNotesStillLoad() throws {
        let (defaults, suite) = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        let legacyJSON = """
        [{"id":"\(id.uuidString)","title":"Стара","priority":"high","isDone":false}]
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "tasks")
        let repository = UserDefaultsTaskRepository(defaults: defaults, key: "tasks")

        let loaded = try repository.loadTasks()

        #expect(loaded.count == 1)
        #expect(loaded.first?.id == id)
        #expect(loaded.first?.notes == "")
    }
}
