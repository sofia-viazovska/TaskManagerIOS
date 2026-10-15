//
//  TaskRowView.swift
//  TaskManager
//
//  Рядок списку. Дві незалежні зони дотику: чекбокс (змінює статус) і решта
//  рядка (відкриває деталі). Рядок нічого не знає про роутер і ViewModel —
//  отримує дані й дві дії ззовні, тому його легко використовувати повторно та показувати в #Preview.
//

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let isOverdue: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            CompletionCheckbox(isDone: task.isDone, action: onToggle)

            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.body)
                            .strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        details
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Відкрити деталі задачі")
        }
    }

    /// Пріоритет і дедлайн завжди один під одним: текст вільно переноситься
    /// на будь-якому розмірі екрана й шрифту. (Варіант «в один рядок, а якщо не
    /// вміщується — в стовпчик» через ViewThatFits на найбільшому Dynamic Type
    /// центрував надто широкий вміст і обрізав краї.)
    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            priorityLabel
            dueLabel
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var priorityLabel: some View {
        Label(task.priority.displayName, systemImage: "flag.fill")
            .foregroundStyle(task.priority.color)
    }

    @ViewBuilder
    private var dueLabel: some View {
        if let dueDate = task.dueDate {
            let text = dueDate.formatted(date: .abbreviated, time: .omitted)
            if isOverdue {
                // Не лише колір: ще й слово та значок.
                Label("Прострочено · \(text)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else {
                Label(text, systemImage: "calendar")
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("Без дедлайну", systemImage: "calendar")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    List {
        TaskRowView(
            task: TaskItem(title: "Здати лабу 3", priority: .high, dueDate: .now.addingTimeInterval(86_400)),
            isOverdue: false, onToggle: {}, onOpen: {}
        )
        TaskRowView(
            task: TaskItem(title: "Дуже довга назва задачі, яка не повинна налазити на інші елементи рядка", priority: .low, dueDate: .now.addingTimeInterval(-86_400)),
            isOverdue: true, onToggle: {}, onOpen: {}
        )
    }
}
