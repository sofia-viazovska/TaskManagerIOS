//
//  ContentView.swift
//  TaskManager
//
//  Мінімальний SwiftUI-екран для демонстрації сценарію лаби 1.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var taskList = TaskList(name: "Навчання")

    var body: some View {
        NavigationStack {
            List {
                Section("Підсумок") {
                    Text(taskList.describe())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Задачі") {
                    ForEach(taskList.tasks) { task in
                        Button {
                            taskList.toggleDone(id: task.id)
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
            .navigationTitle(taskList.name)
            .onAppear(perform: runDemoScenario)
        }
    }

    /// Демонстраційний сценарій із завдання: створення задач, додавання їх
    /// до списку, позначення однієї виконаною та вивід відфільтрованого
    /// результату (невиконані задачі) в консоль під час запуску.
    private func runDemoScenario() {
        // Захист від повторного запуску при кожному onAppear.
        guard taskList.tasks.isEmpty else { return }

        taskList.add(TaskItem(title: "Здати лабу 1", priority: .high, dueDate: Date()))
        taskList.add(TaskItem(title: "Прочитати Swift Basics 2.0", priority: .medium))
        taskList.add(TaskItem(title: "Налаштувати git remote", priority: .low, isDone: true))

        // Демонстрація toggleDone: позначаємо першу задачу виконаною.
        if let firstID = taskList.tasks.first?.id {
            taskList.toggleDone(id: firstID)
        }

        print("== \(taskList.describe()) ==")
        for task in taskList.tasks {
            print(task.describe())
        }

        print("Невиконані задачі за пріоритетом:")
        for task in taskList.pendingTasks() {
            print("- \(task.describe())")
        }
    }
}

#Preview {
    ContentView()
}
