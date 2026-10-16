//
//  ContentView.swift
//  TaskManager
//
//  Корінь навігації. Тут маршрути (`TaskRoute`, `TaskModal`) перетворюються
//  на конкретні екрани. Самі екрани нічого не знають один про одного:
//  вони лише викликають методи роутера.
//
//  Карта навігації — у docs/NAVIGATION.md.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var router: AppRouter
    @ObservedObject var serverTasks: ServerTasksViewModel

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Задачі", systemImage: "checklist", value: AppTab.tasks) {
                NavigationStack(path: $router.path) {
                    TaskListScreen(viewModel: viewModel, router: router)
                        .navigationDestination(for: TaskRoute.self) { route in
                            switch route {
                            case .detail(let taskID):
                                TaskDetailScreen(taskID: taskID, viewModel: viewModel, router: router)
                            }
                        }
                }
            }

            Tab("Статистика", systemImage: "chart.bar.fill", value: AppTab.statistics) {
                StatisticsScreen(viewModel: viewModel, router: router)
            }
        }
        // Модальне вікно висить на корені: його можна відкрити з будь-якого екрана стеку.
        .sheet(item: $router.modal) { modal in
            switch modal {
            case .importFromServer:
                ServerImportScreen(viewModel: serverTasks, tasks: viewModel, router: router)
            case .create, .edit:
                TaskEditorScreen(modal: modal, viewModel: viewModel, router: router)
            }
        }
        // Завантаження — один раз для всього застосунку, а не при кожному поверненні на список.
        .task { viewModel.load() }
    }
}

#Preview {
    ContentView(
        viewModel: AppEnvironment.makeDemoViewModel(),
        router: AppEnvironment.makeRouter(),
        serverTasks: AppEnvironment.makeServerTasksViewModel(
            service: MockTodoService(script: [.todos(RemoteTodo.samples)])
        )
    )
}
