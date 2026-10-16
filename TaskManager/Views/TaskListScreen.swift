//
//  TaskListScreen.swift
//  TaskManager
//
//  Екран 1: список задач (корінь стеку). Показує стан ViewModel і передає дії
//  користувача: зміна статусу — у ViewModel, переходи — у Router.
//

import SwiftUI

struct TaskListScreen: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var router: AppRouter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                // Порожній стан — рядок усередині списку, а не накладка поверх нього:
                // на великому шрифті він іде під заголовком і прокручується, а не налазить на нього.
                if viewModel.tasks.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                ForEach(viewModel.tasks) { task in
                    TaskRowView(
                        task: task,
                        isOverdue: viewModel.isOverdue(task),
                        onToggle: { toggle(task) },
                        onOpen: { router.showDetail(of: task.id) }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(task)
                        } label: {
                            Label("Видалити", systemImage: "trash")
                        }
                        Button {
                            router.presentEdit(task.id)
                        } label: {
                            Label("Редагувати", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            } header: {
                Text(viewModel.summary)
                    .textCase(nil)
            }
        }
        // Вставка, видалення й перестановка рядків анімуються лише коли змінився склад/порядок.
        .animation(Motion.animation(Motion.list, reduceMotion: reduceMotion), value: viewModel.tasks.map(\.id))
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                viewMenu
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    router.presentImport()
                } label: {
                    Label("Імпорт із сервера", systemImage: "icloud.and.arrow.down")
                }
                Button {
                    router.presentCreate()
                } label: {
                    Label("Нова задача", systemImage: "plus")
                }
            }
        }
    }

    // MARK: Частини екрана

    private var viewMenu: some View {
        Menu {
            Picker("Сортування", selection: $viewModel.sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.strategy.name).tag(option)
                }
            }
            Toggle("Лише невиконані", isOn: $viewModel.showOnlyPending)
        } label: {
            Label("Вигляд", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                viewModel.showOnlyPending ? "Усе виконано" : "Задач ще немає",
                systemImage: viewModel.showOnlyPending ? "checkmark.seal" : "tray"
            )
        } description: {
            Text(viewModel.showOnlyPending
                 ? "Невиконаних задач немає."
                 : "Натисніть «+», щоб додати першу задачу.")
        } actions: {
            if !viewModel.showOnlyPending {
                Button("Імпортувати із сервера") {
                    router.presentImport()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Дії

    private func toggle(_ task: TaskItem) {
        Motion.perform(reduceMotion: reduceMotion, Motion.list) {
            viewModel.toggleDone(id: task.id)
        }
    }

    private func delete(_ task: TaskItem) {
        Motion.perform(reduceMotion: reduceMotion, Motion.list) {
            viewModel.delete(id: task.id)
        }
    }
}

#Preview {
    NavigationStack {
        TaskListScreen(
            viewModel: {
                let viewModel = AppEnvironment.makeDemoViewModel()
                viewModel.load()
                return viewModel
            }(),
            router: AppEnvironment.makeRouter()
        )
    }
}
