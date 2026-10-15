//
//  Motion.swift
//  TaskManager
//
//  Усі анімації застосунку в одному місці + повага до системного
//  налаштування «Зменшити рух» (Reduce Motion).
//
//  Правила, щоб анімація не заважала взаємодії:
//  • короткі (≤ 0.35 с), без нескінченних циклів;
//  • анімується лише зміна стану (toggle, розгортання), а не «сама по собі»;
//  • `allowsHitTesting` ніде не вимикається — елементи лишаються натискними
//    під час руху, а повторний тап просто перемикає стан ще раз.
//

import SwiftUI

enum Motion {
    /// Чекбокс: пружинний «відскок».
    static let checkbox: Animation = .spring(duration: 0.35, bounce: 0.4)
    /// Розгортання блоку нотаток.
    static let expand: Animation = .easeInOut(duration: 0.25)
    /// Вставка, видалення і перестановка рядків списку.
    static let list: Animation = .snappy(duration: 0.3)

    /// Змінює стан з анімацією, а за ввімкненого «Зменшити рух» — миттєво.
    static func perform(reduceMotion: Bool, _ animation: Animation, _ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(animation, change)
        }
    }

    /// Анімація для `.animation(_:value:)`: `nil` вимикає рух.
    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
