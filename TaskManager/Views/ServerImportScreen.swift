//
//  ServerImportScreen.swift
//  TaskManager
//
//  Екран «Імпорт із сервера» (модальний). Показує чотири стани запиту
//  (завантаження, успіх, немає даних, помилка) — вибір стану робить `switch` по
//  `ServerTasksViewModel.state`. Екран не знає, звідки беруться дані: ні URLSession,
//  ні JSON тут немає. Імпорт у локальний список — через `TaskListViewModel`.
//

import SwiftUI

struct ServerImportScreen: View {
    @ObservedObject var viewModel: ServerTasksViewModel
    @ObservedObject var tasks: TaskListViewModel
    @ObservedObject var router: AppRouter

    /// Лічильник спроб: його зміна перезапускає `.task(id:)` — так працює «Повторити».
    @State private var attempt = 0
    @State private var importError: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ідентичність завантаження: змінився користувач або натиснули «Повторити» —
    /// SwiftUI скасовує попередній запит і запускає новий.
    private struct LoadKey: Equatable {
        let userID: Int
        let attempt: Int
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Імпорт із сервера")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрити") { router.dismissModal() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        userMenu
                    }
                }
        }
        // Запит стартує при появі екрана й при зміні ключа; при закритті екрана
        // SwiftUI сам скасовує задачу (а з нею і запит у URLSession).
        .task(id: LoadKey(userID: viewModel.userID, attempt: attempt)) {
            await viewModel.load()
        }
        .animation(Motion.animation(Motion.list, reduceMotion: reduceMotion), value: viewModel.state)
        .alert(
            "Не вдалося імпортувати",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            ),
            presenting: importError
        ) { _ in
            Button("Гаразд", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: Стани

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Завантаження…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            ContentUnavailableView {
                Label("Немає даних", systemImage: "tray")
            } description: {
                Text("Сервер не повернув жодної задачі для користувача \(viewModel.userID).")
            } actions: {
                Button("Оновити") { attempt += 1 }
                    .buttonStyle(.bordered)
            }

        case .failed(let error):
            ContentUnavailableView {
                Label("Не вдалося завантажити", systemImage: icon(for: error))
            } description: {
                Text(error.userMessage)
            } actions: {
                if error.isRetryable {
                    Button("Повторити") { attempt += 1 }
                        .buttonStyle(.borderedProminent)
                }
            }

        case .loaded(let todos):
            todoList(todos)
        }
    }

    private func todoList(_ todos: [RemoteTodo]) -> some View {
        let pending = newTodos(in: todos)
        return List {
            if !pending.isEmpty {
                Section {
                    Button("Додати всі нові (\(pending.count))") {
                        importAll(pending)
                    }
                }
            }

            Section {
                ForEach(todos) { todo in
                    row(for: todo)
                }
            } header: {
                Text("Задачі користувача \(viewModel.userID) · \(todos.count)")
                    .textCase(nil)
            }
        }
    }

    private func row(for todo: RemoteTodo) -> some View {
        let isAdded = tasks.hasTask(titled: todo.makeDraft().title)
        return VStack(alignment: .leading, spacing: 8) {
            Text(todo.title)

            Text(todo.completed ? "Сервер · #\(todo.id) · виконана" : "Сервер · #\(todo.id)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isAdded {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Додано")
                }
                .font(.caption)
                .foregroundStyle(.green)
            } else {
                Button("Додати до списку") { importOne(todo) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private var userMenu: some View {
        Menu {
            Picker("Користувач", selection: $viewModel.userID) {
                ForEach(Array(ServerTasksViewModel.userIDRange), id: \.self) { id in
                    Text("Користувач \(id)").tag(id)
                }
            }
        } label: {
            Label("Користувач \(viewModel.userID)", systemImage: "person.crop.circle")
        }
    }

    // MARK: Дії

    private func newTodos(in todos: [RemoteTodo]) -> [RemoteTodo] {
        todos.filter { !tasks.hasTask(titled: $0.makeDraft().title) }
    }

    private func importOne(_ todo: RemoteTodo) {
        do {
            try tasks.create(todo.makeDraft(), isDone: todo.completed)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func importAll(_ todos: [RemoteTodo]) {
        for todo in todos where !tasks.hasTask(titled: todo.makeDraft().title) {
            do {
                try tasks.create(todo.makeDraft(), isDone: todo.completed)
            } catch {
                importError = error.localizedDescription
                return
            }
        }
    }

    private func icon(for error: NetworkError) -> String {
        switch error.category {
        case .transport: return "wifi.slash"
        case .http: return "exclamationmark.icloud"
        case .decoding: return "doc.badge.gearshape"
        case .other: return "exclamationmark.triangle"
        }
    }
}

#Preview("Успіх") {
    ServerImportScreen(
        viewModel: AppEnvironment.makeServerTasksViewModel(
            service: MockTodoService(script: [.todos(RemoteTodo.samples)])
        ),
        tasks: AppEnvironment.makeDemoViewModel(),
        router: AppEnvironment.makeRouter()
    )
}

#Preview("Помилка") {
    ServerImportScreen(
        viewModel: AppEnvironment.makeServerTasksViewModel(
            service: MockTodoService(script: [.failure(.httpStatus(500))])
        ),
        tasks: AppEnvironment.makeDemoViewModel(),
        router: AppEnvironment.makeRouter()
    )
}
