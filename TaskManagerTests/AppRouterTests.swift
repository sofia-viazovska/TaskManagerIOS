//
//  AppRouterTests.swift
//  TaskManagerTests
//
//  Навігацію перевіряємо без UI: роутер — звичайний клас зі станом,
//  тому достатньо викликати методи й подивитися на `path`, `modal`, `selectedTab`.
//

import Foundation
import Testing
@testable import TaskManager

@MainActor
struct AppRouterTests {
    @Test func startsOnTasksTabWithEmptyStackAndNoModal() {
        let router = AppRouter()

        #expect(router.selectedTab == .tasks)
        #expect(router.path.isEmpty)
        #expect(router.modal == nil)
    }

    @Test func showDetailPushesRouteWithTaskID() {
        let router = AppRouter()
        let id = UUID()

        router.showDetail(of: id)

        #expect(router.path == [.detail(id)])
    }

    @Test func repeatedShowDetailForSameTaskDoesNotDuplicateRoute() {
        let router = AppRouter()
        let id = UUID()

        router.showDetail(of: id)
        router.showDetail(of: id)
        router.showDetail(of: id)

        #expect(router.path.count == 1)
    }

    @Test func popReturnsToPreviousScreenAndIsSafeOnEmptyStack() {
        let router = AppRouter()
        router.showDetail(of: UUID())

        router.pop()
        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test func repeatedPushAndPopLeavesCleanState() {
        let router = AppRouter()

        for _ in 0..<5 {
            router.showDetail(of: UUID())
            router.pop()
        }

        #expect(router.path.isEmpty)
    }

    @Test func presentCreateAndEditSetModalAndDismissClearsIt() {
        let router = AppRouter()
        let id = UUID()

        router.presentCreate()
        #expect(router.modal == .create)
        router.dismissModal()
        #expect(router.modal == nil)

        router.presentEdit(id)
        #expect(router.modal == .edit(id))
        router.dismissModal()
        #expect(router.modal == nil)
    }

    @Test func secondModalIsIgnoredWhileFirstIsOnScreen() {
        let router = AppRouter()

        router.presentCreate()
        router.presentEdit(UUID())

        #expect(router.modal == .create)
    }

    @Test func modalCanBeOpenedOverPushedDetail() {
        let router = AppRouter()
        let id = UUID()
        router.showDetail(of: id)

        router.presentEdit(id)

        // Стек і модальне вікно незалежні: після закриття форми деталі на місці.
        #expect(router.path == [.detail(id)])
        router.dismissModal()
        #expect(router.path == [.detail(id)])
    }

    @Test func showTaskListSwitchesTabAndClearsStack() {
        let router = AppRouter()
        router.showDetail(of: UUID())
        router.showStatistics()
        #expect(router.selectedTab == .statistics)

        router.showTaskList()

        #expect(router.selectedTab == .tasks)
        #expect(router.path.isEmpty)
    }

    @Test func modalIdentifiersDifferPerTask() {
        let first = UUID()
        let second = UUID()

        #expect(TaskModal.create.id == "create")
        #expect(TaskModal.edit(first).id != TaskModal.edit(second).id)
    }

    // MARK: Імпорт із сервера (практична 4)

    @Test func presentImportOpensImportModal() {
        let router = AppRouter()

        router.presentImport()

        #expect(router.modal == .importFromServer)
    }

    @Test func importModalHasOwnIdentifier() {
        #expect(TaskModal.importFromServer.id == "import")
        #expect(TaskModal.importFromServer.id != TaskModal.create.id)
    }

    @Test func secondModalIsIgnoredWhileImportIsOpen() {
        let router = AppRouter()
        router.presentImport()

        router.presentCreate()
        router.presentEdit(UUID())

        #expect(router.modal == .importFromServer)
    }

    @Test func dismissClosesImportModal() {
        let router = AppRouter()
        router.presentImport()

        router.dismissModal()

        #expect(router.modal == nil)
    }
}
