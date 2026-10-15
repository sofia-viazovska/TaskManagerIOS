//
//  TaskDraft.swift
//  TaskManager
//
//  Чернетка задачі: значення, які користувач вводить у формі редактора.
//

import Foundation

/// Дані форми створення/редагування. Це значення (struct): редактор працює зі
/// своєю копією, а оригінал змінюється лише після успішного «Зберегти».
/// Тому скасування форми не залишає жодних слідів у списку.
struct TaskDraft: Equatable {
    var title: String = ""
    var priority: Priority = .medium
    var dueDate: Date?
    var notes: String = ""
}
