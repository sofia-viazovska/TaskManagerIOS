//
//  AppRouter.swift
//  TaskManager
//
//  Router: єдине місце, яке знає «куди можна перейти» і «де зараз користувач».
//  Екрани не створюють один одного і не тримають шляху — вони лише просять
//  роутер: `router.showDetail(of: id)`, `router.presentEdit(id)`, `router.dismissModal()`.
//
//  Що тут НЕ живе: дані задач (це ViewModel) і самі екрани (це ContentView,
//  який перетворює маршрути на View у `navigationDestination` / `sheet`).
//  Тому роутер можна перевірити звичайним unit-тестом без жодного UI.
//
//  Роутер не посилається ні на ViewModel, ні на екрани, а екрани не передають
//  у нього замикань, що захоплюють self → циклів утримання (retain cycles) немає:
//  стрілки власності йдуть лише «зверху вниз» (App → Router/ViewModel → екрани).
//

import Foundation
import Combine

/// Вкладки кореневого `TabView`.
nonisolated enum AppTab: Hashable {
    case tasks
    case statistics
}

/// Маршрути, які кладуться в стек (push). У маршруті — лише ідентифікатор задачі,
/// а не копія самої задачі: екран деталей завжди читає актуальні дані з ViewModel.
nonisolated enum TaskRoute: Hashable {
    case detail(TaskItem.ID)
}

/// Екрани, що відкриваються модально (sheet). Це окрема сутність від `TaskRoute`:
/// стек і модальне вікно мають різний життєвий цикл.
nonisolated enum TaskModal: Identifiable, Hashable {
    case create
    case edit(TaskItem.ID)
    /// Екран «Імпорт із сервера» (практична 4).
    case importFromServer

    /// Стабільний ідентифікатор для `.sheet(item:)`: різні задачі — різні вікна.
    var id: String {
        switch self {
        case .importFromServer:
            return "import"
        case .create:
            return "create"
        case .edit(let taskID):
            return "edit-\(taskID.uuidString)"
        }
    }
}

final class AppRouter: ObservableObject {
    /// Активна вкладка.
    @Published var selectedTab: AppTab = .tasks
    /// Стек навігації вкладки «Задачі». `NavigationStack(path:)` читає і змінює його
    /// напряму — тому свайп «назад» теж потрапляє сюди, і стан не розходиться з екраном.
    @Published var path: [TaskRoute] = []
    /// Поточне модальне вікно (або `nil`).
    @Published var modal: TaskModal?

    // MARK: Push / pop

    /// Відкриває деталі задачі. Повторний виклик для вже відкритих деталей
    /// ігнорується — подвійний тап не додає в стек дублікат.
    func showDetail(of id: TaskItem.ID) {
        selectedTab = .tasks
        let route = TaskRoute.detail(id)
        guard path.last != route else { return }
        path.append(route)
    }

    /// Крок назад (кнопка в коді, наприклад після видалення задачі).
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    // MARK: Модальні вікна

    func presentCreate() {
        present(.create)
    }

    func presentEdit(_ id: TaskItem.ID) {
        present(.edit(id))
    }

    func presentImport() {
        present(.importFromServer)
    }

    func dismissModal() {
        modal = nil
    }

    // MARK: Вкладки

    /// Повертає на початок списку задач: перемикає вкладку і очищає стек.
    func showTaskList() {
        selectedTab = .tasks
        popToRoot()
    }

    func showStatistics() {
        selectedTab = .statistics
    }

    // MARK: Приватне

    /// Одночасно відкрите лише одне модальне вікно: другий виклик, поки перше
    /// на екрані, ігнорується (інакше швидкі повторні тапи підміняли б форму).
    private func present(_ newModal: TaskModal) {
        guard modal == nil else { return }
        modal = newModal
    }
}
