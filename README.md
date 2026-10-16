# TaskManager

Навчальний iOS-застосунок для планування задач (SwiftUI, архітектура MVVM).
Розвивається послідовно в практичних роботах; кожна здається окремим тегом.

| Робота | Тема | Тег |
|---|---|---|
| 1 | Основа проєкту, Git, базові конструкції Swift | `practical-1` |
| 2 | Архітектура (MVVM), патерни проєктування, SOLID | `practical-2` |
| 3 | Навігація: Router, push / modal, анімація | `practical-3` |
| 4 | Мережа: URLSession, async/await, Decodable, стани екрана | `practical-4` |

## Предметна область

Застосунок для персонального планування задач. Користувач створює задачі з
пріоритетом і необов'язковим дедлайном, позначає їх виконаними, сортує й фільтрує
список. Дані зберігаються між запусками.

Сутності:
- **TaskItem** — окрема задача: назва, пріоритет, необов'язковий дедлайн, статус виконання, нотатки.
- **TaskList** — іменований список задач: додавання, редагування, видалення, позначення виконаною, вибірка невиконаних, статистика.
- **TaskDraft** — чернетка задачі у формі редагування (копія полів, яку можна скасувати).

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

Сценарій для перевірки (навігація, лаба 3): вкладка «Задачі» → «+» → заповнити форму →
«Зберегти» → тап по задачі (деталі) → «Змінити» → «Зберегти» → назад до списку →
вкладка «Статистика». Детальні кроки — у [docs/NAVIGATION.md](docs/NAVIGATION.md).

Сценарій для перевірки (мережа, лаба 4): вкладка «Задачі» → кнопка імпорту (хмаринка зі стрілкою) →
з'явиться список задач із сервера → «Додати до списку» → «Закрити». Стани й аргументи запуску — нижче та в
[docs/NETWORKING.md](docs/NETWORKING.md). Для реального запиту потрібен інтернет.

**Демо-режим.** Edit Scheme → Run → Arguments → Arguments Passed On Launch → додати
`-demo`. Застосунок стартує з готовими задачами в пам'яті, без запису в `UserDefaults`.
Це демонструє заміну залежності без змін у ViewModel (див. `docs/ARCHITECTURE.md`).

**Мережеві сценарії.** Edit Scheme → Run → Arguments → один з аргументів `-network-empty`,
`-network-error`, `-network-offline`, `-network-decoding`, `-network-flaky`, `-network-slow`
підставляє керований mock замість реальної мережі (таблиця — у розділі «Мережа»).

## Тести

Тести лежать у `TaskManagerTests/` (Swift Testing) і перевіряють логіку та навігацію без UI
та без реального сховища (`AppRouterTests` — переходи, `TaskListViewModelTests` — дані, `NetworkingTests` / `ServerTasksViewModelTests` / `ImportFromServerTests` — мережа без інтернету). Щоб запустити їх, потрібен тестовий таргет:

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
├── TaskManagerApp.swift       — точка входу, власник ViewModel і Router
├── ContentView.swift          — корінь навігації: TabView, NavigationStack, sheet
├── App/AppEnvironment.swift   — composition root (вибір реалізацій залежностей)
├── Navigation/AppRouter.swift — Router: вкладка, стек, модальне вікно
├── Views/                     — екрани: список, деталі, редактор, статистика, імпорт із сервера
│   └── Components/            — CompletionCheckbox, TaskRowView, Motion, Priority+Color
├── ViewModels/                — TaskListViewModel, SortOption, ServerTasksViewModel
├── Networking/                — Endpoint, APIClient, HTTPTransport, NetworkError, RemoteTodo, TodoService, MockTodoService
├── Models/                    — TaskItem, Priority, TaskList, TaskDraft, TaskStatistics
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

«Додати задачу»: `TaskEditorScreen` → `TaskListViewModel.create` → `TaskItemBuilder.build` →
`TaskList.add` → `TaskRepository.saveTasks` → `refresh()` (фільтр + Strategy) →
`@Published tasks` → усі екрани оновлюються. Діаграма послідовності — в
`docs/ARCHITECTURE.md`.

## Навігація (практична робота 3)

Зв'язний сценарій із чотирьох екранів: **список → деталі (push) → форма створення /
редагування (sheet)** + вкладка **«Статистика»**. Навігацією керує окремий `AppRouter`
(`NavigationStack` зі шляхом `[TaskRoute]`, модальне вікно `TaskModal`, вкладки `AppTab`);
екрани лише просять роутер про перехід, а між собою передають тільки `id` задачі.
Дані — в єдиному `TaskListViewModel`, тому після створення чи редагування списки, деталі
й статистика оновлюються самі.

Анімація (прив'язана до стану): анімований чекбокс «виконано» (`replace` + `bounce`),
розгортання нотаток на екрані деталей, анімований прогрес у статистиці; за «Зменшити рух»
вимикається.

### Карта навігації

```mermaid
flowchart TD
    subgraph TAB["TabView"]
        subgraph T1["Вкладка «Задачі»: NavigationStack"]
            L["Список задач"] -->|push| D["Деталі задачі"]
        end
        S["Статистика"]
    end
    L -.->|sheet| E["Форма: створення / редагування"]
    D -.->|sheet| E
    S -->|showTaskList| L
```

Повна карта, діаграма передавання даних, таблиця перевірок інтерфейсу та відповіді на
питання для захисту — у **[docs/NAVIGATION.md](docs/NAVIGATION.md)**.

### Короткий сценарій

1. Запустити (⌘R), за потреби з аргументом `-demo`.
2. «+» → ввести назву, пріоритет, дедлайн, нотатки → «Зберегти».
3. Тап по задачі → «Показати нотатки» → «Змінити» → змінити назву → «Зберегти».
4. Повернутися назад — список оновлено. Тап по чекбоксу — анімація статусу.
5. Вкладка «Статистика» — підсумки; «Відкрити список задач» повертає на список.

### Скріншоти

Зроблено в симуляторі Xcode (демо-режим `-demo`) на трьох пристроях.

| Файл | Пристрій | Що показує |
|---|---|---|
| [`01-list-iphone-air.png`](docs/screenshots/01-list-iphone-air.png) | iPhone Air | список задач: виконана, прострочена, звичайні |
| [`02-detail-iphone-air.png`](docs/screenshots/02-detail-iphone-air.png) | iPhone Air | деталі задачі, нотатки розгорнуто |
| [`03-editor-iphone-air.png`](docs/screenshots/03-editor-iphone-air.png) | iPhone Air | редагування з клавіатурою, поле нотаток видно |
| [`04-statistics-iphone-air.png`](docs/screenshots/04-statistics-iphone-air.png) | iPhone Air | вкладка «Статистика» |
| `05-list-small-iphone-large-text-1/2/3.png` ([1](docs/screenshots/05-list-small-iphone-large-text-1.png), [2](docs/screenshots/05-list-small-iphone-large-text-2.png), [3](docs/screenshots/05-list-small-iphone-large-text-3.png)) | iPhone SE | список на найбільшому Dynamic Type (Accessibility 5), три позиції прокрутки: текст переноситься й не накладається |
| [`06-editor-small-iphone-keyboard.png`](docs/screenshots/06-editor-small-iphone-keyboard.png) | iPhone SE | форма з клавіатурою: поле нотаток і кнопки не перекриті |
| [`07-list-ipad.png`](docs/screenshots/07-list-ipad.png) | iPad 13" | список на планшеті |
| [`08-editor-ipad.png`](docs/screenshots/08-editor-ipad.png) | iPad 13" | форма створення як sheet, «Зберегти» вимкнена до введення назви |

## Мережа (практична робота 4)

Нова функція — екран **«Імпорт із сервера»**: застосунок завантажує задачі з відкритого API
і дає додати їх у локальний список (окремо або всі нові). Мережевий шар — окремі компоненти в
`TaskManager/Networking/`; екрани й ViewModel працюють через протокол `TodoService` і нічого не
знають про `URLSession` та JSON. Повний опис, схеми, таблиця помилок і відповіді на питання для
захисту — у **[docs/NETWORKING.md](docs/NETWORKING.md)**.

### Джерело даних

**JSONPlaceholder** — відкритий тестовий REST API без авторизації.

| | |
|---|---|
| Base URL | `https://jsonplaceholder.typicode.com` |
| Endpoint | `GET /todos` |
| Параметри | `userId` (1…10) — чиї задачі; `_limit` — скільки (у застосунку 20) |
| Заголовки | `Accept: application/json` |
| Відповідь | JSON-масив `{ "userId": 1, "id": 1, "title": "…", "completed": false }` → `RemoteTodo: Decodable` |
| Авторизація | не потрібна |

### Шари

`ServerImportScreen` → `ServerTasksViewModel` (`@Published state: ImportState`) → `TodoService` (протокол) →
`RemoteTodoService` → `APIClient` → `HTTPTransport` (протокол, реалізація — `URLSession`).
Залежності передаються через `init`, реалізацію обирає `AppEnvironment`. Оновлення стану — на `MainActor`;
`await` не блокує головний потік.

### Стани екрана й як їх перевірити

Edit Scheme → Run → Arguments → Arguments Passed On Launch → додати один аргумент (решту зняти) → ⌘R → кнопка імпорту.

| Стан | Аргумент запуску | Що має бути на екрані |
|---|---|---|
| Успіх (**реальний запит**) | *жодного* | список із 20 задач; у консолі Xcode: `[Network] GET … -> 200, … bytes` |
| Завантаження | `-network-slow` | «Завантаження…» приблизно 3 секунди, потім список |
| Немає даних | `-network-empty` | «Немає даних» + «Оновити» |
| Помилка сервера (HTTP 500) | `-network-error` | «Сервер тимчасово недоступний (код 500)…» + «Повторити» |
| Помилка мережі | `-network-offline` | «Немає з'єднання з інтернетом…» + «Повторити» |
| Помилка формату (декодування) | `-network-decoding` | «Сервер повернув дані в неочікуваному форматі.» + «Повторити» |
| Повтор після збою | `-network-flaky` | перший запит — помилка 503, після «Повторити» — список |

Різні групи помилок: **транспорт** (`.transport`: немає зв'язку, таймаут), **HTTP-статус** (`.httpStatus`:
статус не 2xx — перевіряється *до* декодування), **декодування** (`.decoding`: формат відповіді не збігається з моделлю).

### Як перевірити помилки без залежності від зовнішнього API

- Юніт-тести (⌘U): `NetworkingTests` (заглушка транспорту повертає потрібні статуси, байти й `URLError`),
  `ServerTasksViewModelTests` (mock-сервіс), `ImportFromServerTests` (імпорт у локальний список).
- Аргументи запуску `-network-*` (таблиця вище) підставляють `MockTodoService` у реальному застосунку.

### Скріншоти (практична робота 4)

| Файл | Пристрій | Що показує |
|---|---|---|
| [`09-import-loaded-iphone-air.png`](docs/screenshots/09-import-loaded-iphone-air.png) | iPhone Air | успіх, реальний запит: список із 20 задач сервера; перші три вже додані, нагорі «Додати всі нові (17)» |
| [`10-import-loading-iphone-air.png`](docs/screenshots/10-import-loading-iphone-air.png) | iPhone Air | стан «Завантаження…» (`-network-slow`) |
| [`11-import-empty-iphone-air.png`](docs/screenshots/11-import-empty-iphone-air.png) | iPhone Air | стан «Немає даних» + «Оновити» (`-network-empty`) |
| [`12-import-error-http-iphone-air.png`](docs/screenshots/12-import-error-http-iphone-air.png) | iPhone Air | HTTP-помилка 500 + «Повторити» (`-network-error`) |
| [`13-xcode-console-request.png`](docs/screenshots/13-xcode-console-request.png) | Xcode | консоль із фільтром `[Network]`: `GET …/todos?userId=1&_limit=20 -> 200, 2271 bytes` — доказ реального запиту |
| [`14-import-offline-iphone-air.png`](docs/screenshots/14-import-offline-iphone-air.png) | iPhone Air | транспортна помилка: немає інтернету (`-network-offline`) |
| [`15-import-decoding-iphone-air.png`](docs/screenshots/15-import-decoding-iphone-air.png) | iPhone Air | помилка декодування: неочікуваний формат (`-network-decoding`) |
| [`17-list-after-import-iphone-air.png`](docs/screenshots/17-list-after-import-iphone-air.png) | iPhone Air | основний список після імпорту: серверні задачі поруч із локальними |
| [`18-import-ipad.png`](docs/screenshots/18-import-ipad.png) | iPad 13" | екран імпорту як sheet на планшеті |

## Де в коді базові конструкції Swift (практична робота 1)

| Конструкція | Де |
|---|---|
| `struct` | `TaskItem`, `TaskItemBuilder`, стратегії сортування — семантика значення |
| `class` | `TaskList`, `TaskListViewModel`, `AppRouter`, репозиторії — семантика посилання |
| `protocol` | `Describable`, `TaskRepository`, `TaskSortStrategy`, `TodoService`, `HTTPTransport` |
| `enum` | `Priority`, `SortOption`, `TaskItemBuilderError`, `TaskRoute`, `TaskModal`, `ImportState`, `NetworkError` |
| `var` / `let` | властивості моделей, локальні змінні |
| властивості, методи, ініціалізація | `TaskItem.init`, `TaskList.add/toggleDone`, обчислювані `completedCount`, `titles` |
| колекція | `[TaskItem]` у `TaskList.tasks` |
| optional + безпечне розгортання | `TaskItem.dueDate: Date?` — `if let` у `TaskItem.describe()` та `TaskListViewModel.draft(for:)`, `guard let` у `TaskList.toggleDone` |
| умовна конструкція | `if/else`, `switch` у `Priority`, `TaskItem.describe()`, `DueDateSortStrategy` |
| обробка колекції | `filter` (`TaskList.pendingTasks`), `map` (`TaskList.titles`), `sorted` (стратегії) |

Початкова версія для лаби 1 лежить за тегом `practical-1` (`git checkout practical-1`).

## Git

`.gitignore` виключає користувацькі файли Xcode (`xcuserdata/`), кеші збірки
(`DerivedData/`, `build/`, `.build/`) та системні файли macOS (`.DS_Store`) —
під контролем версій залишаються лише файли проєкту, потрібні для збірки.

Коміти практичної роботи 2: MVVM-каркас → патерни (Builder, Adapter, Strategy) →
документація, тести, README.

Коміти практичної роботи 3: код (модель, ViewModel, Router, екрани, анімація) і тести →
документація (`docs/NAVIGATION.md`), README, скріншоти. Тег: `practical-3`.

Коміти практичної роботи 4: мережевий шар (`Networking/`) і тести → екран імпорту, ViewModel,
аргументи запуску → документація (`docs/NETWORKING.md`), README, скріншоти. Тег: `practical-4`.
