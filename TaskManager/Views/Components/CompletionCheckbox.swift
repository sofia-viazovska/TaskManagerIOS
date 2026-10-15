//
//  CompletionCheckbox.swift
//  TaskManager
//
//  Анімований чекбокс «виконано». Анімація прив'язана до стану `isDone`:
//  значок змінюється з ефектом replace, а при позначенні ще й «підстрибує».
//  Область натискання — не менше 44×44 pt.
//

import SwiftUI

struct CompletionCheckbox: View {
    let isDone: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isDone ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                // За «Зменшити рух» значення не змінюється → ефект не запускається.
                .symbolEffect(.bounce, value: reduceMotion ? false : isDone)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Motion.animation(Motion.checkbox, reduceMotion: reduceMotion), value: isDone)
        .accessibilityLabel(isDone ? "Виконано" : "Не виконано")
        .accessibilityHint("Двічі торкніться, щоб змінити статус")
    }
}

#Preview {
    struct Demo: View {
        @State private var isDone = false
        var body: some View {
            CompletionCheckbox(isDone: isDone) { isDone.toggle() }
        }
    }
    return Demo()
}
