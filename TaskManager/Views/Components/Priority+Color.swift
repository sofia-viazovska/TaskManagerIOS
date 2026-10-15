//
//  Priority+Color.swift
//  TaskManager
//
//  Відображення пріоритету в UI. Модель `Priority` не знає про SwiftUI —
//  колір додається розширенням лише у шарі View.
//

import SwiftUI

extension Priority {
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}
