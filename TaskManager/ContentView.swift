//
//  ContentView.swift
//  TaskManager
//
//  View (MVVM): лише відображає стан ViewModel і передає їй дії користувача.
//  Тут немає створення моделей, роботи зі сховищем чи бізнес-правил.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TaskListViewModel

    // Тимчасовий стан форми — суто питання UI, тому живе у View.
    @State private var newTitle = ""
    @State private var newPriority: Priority = .medium

    var body: some View {
        NavigationStack {
            List {
                Section("Нова задача") {
                    TextField("Назва задачі", text: $newTitle)

                    Picker("Пріоритет", selection: $newPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("Додати") {
                        viewModel.addTask(title: newTitle, priority: newPriority)
                        if viewModel.errorMessage == nil {
                            newTitle = ""
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }

                Section("Підсумок") {
                    Text(viewModel.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Задачі") {
                    ForEach(viewModel.tasks) { task in
                        Button {
                            viewModel.toggleDone(id: task.id)
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .strikethrough(task.isDone)
                                    Text(task.describe())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .task { viewModel.load() }
        }
    }
}

#Preview {
    ContentView(viewModel: AppEnvironment.makeViewModel())
}
