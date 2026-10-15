# TaskManager

Навчальний iOS-застосунок для планування задач (SwiftUI, архітектура MVVM).
Розвивається послідовно в практичних роботах; кожна здається окремим тегом.

| Робота | Тема | Тег |
|---|---|---|
| 1 | Основа проєкту, Git, базові конструкції Swift | `practical-1` |
| 2 | Архітектура (MVVM), патерни проєктування, SOLID | `practical-2` |

## Предметна область

Застосунок для персонального планування задач. Користувач створює задачі з
пріоритетом і необов'язковим дедлайном, позначає їх виконаними, сортує й фільтрує
список. Дані зберігаються між запусками.

Сутності:
- **TaskItem** — окрема задача: назва, пріоритет, необов'язковий дедлайн, статус виконання.
- **TaskList** — іменований список задач: додавання, позначення виконаною, вибірка невиконаних.

> Названо `TaskItem`, а не `Task`, щоб не конфліктувати з вбудованим типом Swift Concurrency `Task` (async/await).

## Технічні вимоги

- Xcode: 26.6
- Мінімальна підтримувана версія iOS: 26.5 (iPhone та iPad)
- Мова: Swift, інтерфейс — SwiftUI
- Bundle Identifier: `kpi.ios.vybirka.TaskManager`

## Підготовка проєкту

Додаткових залежностей (SPM, CocoaPods) і секретів немає — достатньо клонувати
репозиторій і відкрити `TaskManager.xcodeproj` в Xcode 26.6 або новішому.
Якщо у вас інший Apple ID, у налаштуваннях таргета TaskManager → Signing & Capabilities
оберіть свою Team, щоб запускати на пристрої (для симулятора це не потрібно).

## Запуск проєкту

1. Відкрити `TaskManager.xcodeproj` в Xcode.
2. Обрати симулятор iPhone у верхній панелі.
3. Натиснути ⌘R (Run).

Сценарій для перевірки: ввести назву задачі, обрати пріоритет, за бажанням увімкнути
дедлайн → «Додати»; тапом по задачі перемкнути її статус; у блоці «Вигляд» змінити
сортування або показати лише невиконані; повністю перезапустити застосунок — задачі
залишаться.

**Демо-режим.** Edit Scheme → Run → Arguments → Arguments Passed On Launch → додати
`-demo`. Застосунок стартує з готовими задачами в пам'яті, без запису в `UserDefaults`.
Це демонструє заміну залежності без змін у ViewModel (див. `docs/ARCHITECTURE.md`).

## Тести

Тести лежать у `TaskManagerTests/` (Swift Testing) і перевіряють логіку без UI та без
реального сховища. Щоб запустити їх, потрібен тестовий таргет:

1. File → New → Target… → **Unit Testing Bundle**, назва `TaskManagerTests`, Testing System — Swift Testing.
2. Якщо Xcode створив шаблонний файл `TaskManagerTests.swift`, його можна видалити.
3. Переконатися, що файли з папки `TaskManagerTests/` входять до цього таргета (File Inspector → Target Membership).
4. ⌘U (Product → Test).

## Архітектура (практична робота 2)

Обрано **MVVM**: `ContentView` (View) ↔ `TaskListViewModel` (ViewModel) ↔ `TaskList`,
`TaskItem` (Model) та `TaskRepository` (доступ до даних). Повний опис, схеми
компонентів, обґрунтування вибору, обмеження, пояснення SOLID, перелік виправлених
антипатернів і таблиця «патерн / принцип — компонент — призначення» —
у **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

```
TaskManager/
├── TaskManagerApp.swift       — точка входу, власник ViewModel
├── ContentView.swift          — View
├── App/AppEnvironment.swift   — composition root (вибір реалізацій залежностей)
├── ViewModels/                — TaskListViewModel, SortOption
├── Models/                    — TaskItem, Priority, TaskList
├── Builders/                  — TaskItemBuilder (Builder)
├── Strategies/                — TaskSortStrategy + 3 реалізації (Strategy)
└── Repositories/              — TaskRepository, UserDefaultsTaskRepository (Adapter), InMemoryTaskRepository
```

### Патерни

| Категорія | Патерн | Компонент | Призначення |
|---|---|---|---|
| Породжувальний | Builder | `TaskItemBuilder` | покрокове створення й валідація задачі |
| Структурний | Adapter | `UserDefaultsTaskRepository` | привести `UserDefaults` до інтерфейсу `TaskRepository` |
| Поведінковий | Strategy | `TaskSortStrategy` та реалізації | взаємозамінні способи сортування |

### Єдиний сценарій через компоненти

«Додати задачу»: `ContentView` → `TaskListViewModel.addTask` → `TaskItemBuilder.build` →
`TaskList.add` → `TaskRepository.saveTasks` → `refresh()` (фільтр + Strategy) →
`@Published tasks` → `ContentView` оновлюється. Діаграма послідовності — в
`docs/ARCHITECTURE.md`.

## Де в коді базові конструкції Swift (практична робота 1)

| Конструкція | Де |
|---|---|
| `struct` | `TaskItem`, `TaskItemBuilder`, стратегії сортування — семантика значення |
| `class` | `TaskList`, `TaskListViewModel`, репозиторії — семантика посилання |
| `protocol` | `Describable`, `TaskRepository`, `TaskSortStrategy` |
| `enum` | `Priority`, `SortOption`, `TaskItemBuilderError` |
| `var` / `let` | властивості моделей, локальні змінні |
| властивості, методи, ініціалізація | `TaskItem.init`, `TaskList.add/toggleDone`, обчислювані `completedCount`, `titles` |
| колекція | `[TaskItem]` у `TaskList.tasks` |
| optional + безпечне розгортання | `TaskItem.dueDate: Date?` — `if let` у `TaskItem.describe()` та `TaskListViewModel.addTask`, `guard let` у `TaskList.toggleDone` |
| умовна конструкція | `if/else`, `switch` у `Priority`, `TaskItem.describe()`, `DueDateSortStrategy` |
| обробка колекції | `filter` (`TaskList.pendingTasks`), `map` (`TaskList.titles`), `sorted` (стратегії) |

Початкова версія для лаби 1 лежить за тегом `practical-1` (`git checkout practical-1`).

## Git

`.gitignore` виключає користувацькі файли Xcode (`xcuserdata/`), кеші збірки
(`DerivedData/`, `build/`, `.build/`) та системні файли macOS (`.DS_Store`) —
під контролем версій залишаються лише файли проєкту, потрібні для збірки.

Коміти практичної роботи 2: MVVM-каркас → патерни (Builder, Adapter, Strategy) →
документація, тести, README.
