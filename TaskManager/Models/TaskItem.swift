//
//  TaskItem.swift
//  TaskManager
//
//  Модель однієї задачі та пов'язані базові типи.
//
//  Названо TaskItem, а не Task, щоб не конфліктувати з вбудованим типом
//  Swift Concurrency `Task` (async/await) — він знадобиться в наступних лабах.
//

import Foundation

/// Спільний протокол для сутностей, які вміють описувати себе текстом.
/// Його реалізують і `TaskItem`, і `TaskList` — це демонструє, як протокол
/// дозволяє працювати з різними типами через єдиний інтерфейс.
protocol Describable {
    func describe() -> String
}

/// Пріоритет задачі.
enum Priority: String, CaseIterable, Comparable {
    case low
    case medium
    case high

    /// Внутрішній порядок для порівняння пріоритетів між собою.
    private var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    var displayName: String {
        switch self {
        case .low: return "Низький"
        case .medium: return "Середній"
        case .high: return "Високий"
        }
    }
}

/// Одна задача.
///
/// `TaskItem` навмисно зроблена `struct`, а не `class`: це семантика значення —
/// коли задача передається чи копіюється, кожна копія повністю незалежна
/// і зміна однієї не впливає на іншу. Це природньо для маленької,
/// самодостатньої одиниці даних.
struct TaskItem: Identifiable, Describable {
    let id: UUID
    var title: String
    var priority: Priority
    var dueDate: Date?
    var isDone: Bool

    /// `id` за замовчуванням генерується, але його можна передати явно —
    /// це потрібно, щоб відновити збережену задачу з тим самим ідентифікатором.
    init(id: UUID = UUID(), title: String, priority: Priority = .medium, dueDate: Date? = nil, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.isDone = isDone
    }

    /// Текстовий опис задачі. Демонструє безпечне розгортання optional
    /// значення `dueDate` через `if let`.
    func describe() -> String {
        var parts = ["\"\(title)\"", "пріоритет: \(priority.displayName)"]

        if let dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("дедлайн: \(formatter.string(from: dueDate))")
        } else {
            parts.append("без дедлайну")
        }

        parts.append(isDone ? "виконано" : "у роботі")
        return parts.joined(separator: ", ")
    }
}
