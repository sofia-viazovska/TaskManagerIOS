//
//  RemoteTodo.swift
//  TaskManager
//
//  DTO (Data Transfer Object): точно те, що повертає сервер. Окремий від `TaskItem`,
//  як `TaskRecord` для сховища: формат сервера може змінитися, а доменна модель — ні.
//
//  Приклад елемента відповіді JSONPlaceholder `GET /todos`:
//  { "userId": 1, "id": 1, "title": "delectus aut autem", "completed": false }
//

import Foundation

nonisolated struct RemoteTodo: Decodable, Equatable, Identifiable {
    let userID: Int
    let id: Int
    let title: String
    let completed: Bool

    /// Відповідність Swift-імен ключам JSON (`userId` → `userID`).
    /// Якщо в JSON немає одного з цих ключів або тип інший — `JSONDecoder` кине `DecodingError`.
    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case id
        case title
        case completed
    }
}

extension RemoteTodo {
    /// Перетворення серверної задачі на чернетку локальної (маппінг DTO → модель застосунку).
    /// Назву обрізаємо до ліміту `TaskItemBuilder`, щоб довгий заголовок не зламав імпорт.
    func makeDraft() -> TaskDraft {
        let limit = TaskItemBuilder.maxTitleLength
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return TaskDraft(
            title: String(trimmed.prefix(limit)),
            priority: .medium,
            dueDate: nil,
            notes: "Імпортовано з сервера (JSONPlaceholder, id \(id))."
        )
    }
}
