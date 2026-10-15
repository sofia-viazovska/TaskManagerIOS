//
//  TaskEditorScreen.swift
//  TaskManager
//
//  Екран 3: створення / редагування задачі (модальне вікно, sheet).
//
//  Форма працює з власною копією — `TaskDraft`. Оригінал у ViewModel змінюється
//  лише після успішного «Зберегти», тому «Скасувати» нічого не псує.
//  Результат редагування «повертається» не через замикання, а через ViewModel:
//  список і деталі читають ті самі дані й оновлюються самі.
//

import SwiftUI

struct TaskEditorScreen: View {
    private enum Field: Hashable {
        case title
        case notes
    }

    let modal: TaskModal
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var router: AppRouter

    private let initialDraft: TaskDraft
    @State private var draft: TaskDraft
    @State private var errorMessage: String?
    @State private var showDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(modal: TaskModal, viewModel: TaskListViewModel, router: AppRouter) {
        self.modal = modal
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _router = ObservedObject(wrappedValue: router)

        let start: TaskDraft
        switch modal {
        case .create:
            start = TaskDraft()
        case .edit(let id):
            // Задачу могли видалити, поки відкривали форму — тоді порожня чернетка,
            // а «Зберегти» покаже помилку `taskNotFound`.
            start = viewModel.draft(for: id) ?? TaskDraft()
        }
        initialDraft = start
        _draft = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Назва") {
                    TextField("Що потрібно зробити?", text: $draft.title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .notes }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Пріоритет") {
                    priorityPicker
                }

                Section("Дедлайн") {
                    Toggle("Є дедлайн", isOn: hasDeadline)
                    if draft.dueDate != nil {
                        DatePicker(
                            "Термін",
                            selection: deadline,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                .animation(Motion.animation(Motion.expand, reduceMotion: reduceMotion), value: draft.dueDate != nil)

                Section("Нотатки") {
                    TextField("Додаткові деталі", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedField, equals: .notes)
                }
            }
            // Форма прокручується, а клавіатуру можна сховати жестом або кнопкою «Готово».
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") { save() }
                        .disabled(isTitleBlank)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
            .onChange(of: draft.title) {
                errorMessage = nil
            }
            .confirmationDialog(
                "Відхилити зміни?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Відхилити зміни", role: .destructive) {
                    router.dismissModal()
                }
                Button("Продовжити редагування", role: .cancel) {}
            }
        }
        // Є незбережені зміни — свайп вниз не закриє форму випадково.
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: Елементи форми

    @ViewBuilder
    private var priorityPicker: some View {
        // На великих шрифтах сегменти не вміщуються — перемикаємося на меню.
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Пріоритет", selection: $draft.priority) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Пріоритет", selection: $draft.priority) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    /// `Toggle` працює з Bool, а в чернетці дедлайн — optional `Date?`. Binding їх з'єднує.
    private var hasDeadline: Binding<Bool> {
        Binding(
            get: { draft.dueDate != nil },
            set: { isOn in draft.dueDate = isOn ? viewModel.defaultDeadline : nil }
        )
    }

    private var deadline: Binding<Date> {
        Binding(
            get: { draft.dueDate ?? viewModel.defaultDeadline },
            set: { draft.dueDate = $0 }
        )
    }

    // MARK: Стан форми

    private var navigationTitle: String {
        switch modal {
        case .create: return "Нова задача"
        case .edit: return "Редагування"
        }
    }

    private var isTitleBlank: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        draft != initialDraft
    }

    // MARK: Дії

    private func save() {
        do {
            switch modal {
            case .create:
                try viewModel.create(draft)
            case .edit(let id):
                try viewModel.update(id: id, with: draft)
            }
            focusedField = nil
            router.dismissModal()
        } catch {
            // Помилку показує сама форма: користувач бачить її поруч із полем.
            errorMessage = error.localizedDescription
        }
    }

    private func cancel() {
        if hasChanges {
            focusedField = nil
            showDiscardConfirmation = true
        } else {
            router.dismissModal()
        }
    }
}

#Preview {
    let viewModel = AppEnvironment.makeDemoViewModel()
    viewModel.load()
    return TaskEditorScreen(modal: .create, viewModel: viewModel, router: AppEnvironment.makeRouter())
}
