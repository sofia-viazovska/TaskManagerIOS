//
//  StatisticsScreen.swift
//  TaskManager
//
//  Додаткова вкладка: підсумки по задачах. Читає ті самі дані з ViewModel,
//  тому цифри оновлюються одразу після створення чи зміни задачі на іншій вкладці.
//

import SwiftUI

struct StatisticsScreen: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var router: AppRouter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let stats = viewModel.statistics

        NavigationStack {
            List {
                Section("Прогрес") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(percentText(stats.completionRatio))
                            .font(.largeTitle.bold())
                            .contentTransition(.numericText())
                        ProgressView(value: stats.completionRatio)
                        Text("Виконано \(stats.completed) з \(stats.total)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .animation(Motion.animation(Motion.list, reduceMotion: reduceMotion), value: stats)
                    .accessibilityElement(children: .combine)
                }

                Section("Стан") {
                    LabeledContent("У роботі", value: "\(stats.pending)")
                    LabeledContent("Прострочено", value: "\(stats.overdue)")
                }

                Section("За пріоритетом") {
                    ForEach(Array(Priority.allCases.reversed()), id: \.self) { priority in
                        LabeledContent {
                            Text("\(stats.count(for: priority))")
                        } label: {
                            Label(priority.displayName, systemImage: "flag.fill")
                                .foregroundStyle(priority.color)
                        }
                    }
                }

                Section {
                    Button {
                        router.showTaskList()
                    } label: {
                        Label("Відкрити список задач", systemImage: "checklist")
                    }
                }
            }
            .navigationTitle("Статистика")
        }
    }

    private func percentText(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}

#Preview {
    let viewModel = AppEnvironment.makeDemoViewModel()
    viewModel.load()
    return StatisticsScreen(viewModel: viewModel, router: AppEnvironment.makeRouter())
}
