# Архітектура TaskManager (практичні роботи 2–4)

Документ описує, як розподілено відповідальність у застосунку, які патерни
проєктування й принципи SOLID застосовано та де саме вони у коді.

## 1. Аналіз сценаріїв і компонентів

Основні сценарії: переглянути список задач, додати задачу (з пріоритетом,
необов'язковим дедлайном і нотатками), відкрити деталі, відредагувати чи видалити
задачу, позначити виконаною, змінити сортування, показати лише невиконані, подивитися
статистику, зберегти стан між запусками. З лаби 3 це кілька екранів зі
керованою навігацією — див. [NAVIGATION.md](NAVIGATION.md).

| Відповідальність | Компоненти | Файли |
|---|---|---|
| Представлення | `ContentView` (корінь навігації), `TaskListScreen`, `TaskDetailScreen`, `TaskEditorScreen`, `StatisticsScreen`, компоненти | `ContentView.swift`, `Views/` |
| Навігація | `AppRouter`, `TaskRoute`, `TaskModal`, `AppTab` | `Navigation/` |
| Логіка екрана (презентаційна) | `TaskListViewModel`, `SortOption` | `ViewModels/` |
| Доменна логіка | `TaskList`, `TaskItem`, `Priority`, `TaskDraft`, `TaskStatistics` | `Models/` |
| Створення та валідація задач | `TaskItemBuilder` | `Builders/` |
| Правила впорядкування | `TaskSortStrategy` та 3 реалізації | `Strategies/` |
| Доступ до даних | `TaskRepository` + `UserDefaultsTaskRepository`, `InMemoryTaskRepository` | `Repositories/` |
| Збирання компонентів | `AppEnvironment`, `TaskManagerApp` | `App/`, `TaskManagerApp.swift` |

## 2. Обрана архітектура: MVVM

**Model** — `TaskItem`, `TaskList`, `Priority`: дані та бізнес-правила, нічого не
знають про SwiftUI і про сховище.
**View** — `ContentView` та екрани в `Views/`: лише відображають стан і передають
події; не створюють моделей, не звертаються до сховища, не створюють інші екрани.
**ViewModel** — `TaskListViewModel`: тримає стан екрана (`@Published`), приймає
команди від View, координує Model, Builder, Strategy і Repository.

### Чому саме MVVM

- SwiftUI побудований на декларативному зв'язуванні «стан → екран»: `@Published` у
  `ObservableObject` дає це «з коробки», тож ViewModel природно лягає на фреймворк.
- Проєкт малий: кілька екранів над одним спільним станом. MVC у SwiftUI не має класичного
  Controller, а логіка «розтікається» у View; VIPER (Interactor, Presenter, Router,
  Entity, View) додав би багато шарів без користі для одного екрана.
- ViewModel не залежить від UI-віджетів, тому її логіку можна тестувати без екрана
  (див. розділ 8).

### Обмеження MVVM у цьому проєкті

- Зі зростанням кількості екранів ViewModel може розростися. Тоді логіку треба
  виносити в окремі сервіси/use case-об'єкти.
- Навігації MVVM сам по собі не дає. У лабі 3 її винесено в окремий `AppRouter`
  (див. розділ 10), щоб ViewModel не знала про екрани, а екрани — один про одного.
- Зв'язування стану прихованими оновленнями (`@Published`) ускладнює налагодження
  порівняно з явними викликами.

## 3. Схема компонентів

```mermaid
flowchart LR
    subgraph V["View"]
        CV["ContentView + екрани"]
    end
    subgraph N["Навігація"]
        RT["AppRouter"]
    end
    subgraph VMG["ViewModel"]
        VM["TaskListViewModel"]
        SO["SortOption"]
    end
    subgraph M["Model"]
        TL["TaskList"]
        TI["TaskItem, Priority"]
        B["TaskItemBuilder"]
    end
    subgraph ST["Strategy"]
        S["TaskSortStrategy"]
    end
    subgraph NW["Мережа (практична 4)"]
        SVM["ServerTasksViewModel"]
        TS["TodoService (protocol)"]
        RTS["RemoteTodoService + APIClient"]
        MTS["MockTodoService"]
    end
    subgraph D["Дані"]
        R["TaskRepository (protocol)"]
        UD["UserDefaultsTaskRepository"]
        IM["InMemoryTaskRepository"]
    end
    ENV["AppEnvironment (composition root)"]

    CV -->|дії користувача| VM
    CV -->|команди переходів| RT
    RT -->|"@Published path, modal, tab"| CV
    VM -->|"@Published стан"| CV
    VM --> TL
    VM --> B
    B --> TI
    TL --> TI
    VM --> SO
    SO --> S
    VM -->|залежить від абстракції| R
    UD -.->|реалізує| R
    IM -.->|реалізує| R
    ENV -.->|створює і передає залежності| VM
    CV -->|"завантаження, стан"| SVM
    SVM -->|залежить від абстракції| TS
    RTS -.->|реалізує| TS
    MTS -.->|реалізує| TS
    ENV -.->|обирає реалізацію| SVM
```

### Сценарій «Додати задачу»

```mermaid
sequenceDiagram
    actor U as Користувач
    participant V as TaskEditorScreen
    participant VM as TaskListViewModel
    participant B as TaskItemBuilder
    participant TL as TaskList
    participant R as TaskRepository

    U->>V: вводить назву, натискає «Зберегти»
    V->>VM: create(draft)
    VM->>B: withPriority / withDueDate / withNotes / build()
    B-->>VM: TaskItem або помилка валідації
    VM->>TL: add(task)
    VM->>R: saveTasks(tasks)
    VM->>VM: refresh(): фільтр + сортування (Strategy)
    VM-->>V: змінився @Published tasks
    V-->>U: оновлений список
```

## 4. Архітектура та патерн проєктування

Архітектура визначає **великий розподіл системи на шари** і напрямки залежностей
(тут: View → ViewModel → Model/Repository), вона одна на весь застосунок.
Патерн проєктування розв'язує **локальну повторювану задачу** в межах кількох
класів (створити об'єкт, адаптувати інтерфейс, замінити алгоритм). Патернів у
застосунку багато, і вони живуть усередині шарів архітектури.

## 5. Патерни проєктування

| Патерн | Категорія | Задача | Учасники | Де використано |
|---|---|---|---|---|
| **Builder** | Породжувальний | Створювати `TaskItem` покроково й гарантувати валідність (назва не порожня й не задовга) | Product: `TaskItem`; Builder: `TaskItemBuilder`; Director: `TaskListViewModel`, `AppEnvironment` | `ViewModel.create/update`, `AppEnvironment.demoTasks` |
| **Adapter** | Структурний | Застосунок очікує `TaskRepository` (`[TaskItem]`), а `UserDefaults` працює з `Data` за ключем | Target: `TaskRepository`; Adaptee: `UserDefaults` + `JSONEncoder/Decoder`; Adapter: `UserDefaultsTaskRepository`; Client: `TaskListViewModel` | `AppEnvironment.makeLiveViewModel` |
| **Strategy** | Поведінковий | Змінювати спосіб сортування під час роботи без розгалужень у ViewModel | Strategy: `TaskSortStrategy`; Concrete: `PrioritySortStrategy`, `DueDateSortStrategy`, `TitleSortStrategy`; Context: `TaskListViewModel` | `ViewModel.refresh` |

Навігація (лаба 3) реалізована як **Router** — окремий об'єкт, що володіє станом
переходів (див. розділ 10). Це не патерн із каталогу GoF, а поширений архітектурний
прийом для MVVM.

Додатково (платформний патерн): `@Published` + `ObservableObject` — це **Observer**:
View підписується на зміни стану ViewModel і перемальовується автоматично.

## 6. Принципи SOLID

**S — Single Responsibility.** Кожен клас має одну причину змінюватися:
`TaskList` — правила списку, `TaskListViewModel` — стан екрана, `TaskRepository` —
зберігання, `TaskItemBuilder` — створення і валідація, `TaskSortStrategy` —
порядок. `ContentView` лише малює.

**O — Open/Closed.** Новий спосіб сортування — це новий тип-стратегія; нове
сховище — новий тип, що реалізує `TaskRepository`. Код `TaskListViewModel` не
змінюється. Єдина точка розширення, яку потрібно дописати вручну, —
один `case` у `SortOption`.

**L — Liskov Substitution.** `InMemoryTaskRepository` і `UserDefaultsTaskRepository`
взаємозамінні: після `saveTasks(x)` обидва повертають `x` у `loadTasks()`. Це
перевіряє один і той самий контрактний тест для обох реалізацій.

**I — Interface Segregation.** Протоколи малі: `TaskRepository` має 2 методи,
`TaskSortStrategy` — 2 члени, `Describable` — 1. View не бачить ні репозиторій,
ні `TaskList`, лише ViewModel.

**D — Dependency Inversion.** `TaskListViewModel` залежить від абстракцій
(`any TaskRepository` і функція `now: () -> Date`), а не від `UserDefaults` чи
`Date()`. Конкретні реалізації обирає `AppEnvironment`.

### Dependency Injection і Dependency Inversion

**Dependency Inversion** — принцип про *напрямок* залежностей: і високорівневий
код (ViewModel), і низькорівневий (UserDefaults) залежать від абстракції
(`TaskRepository`), яку визначає високий рівень. **Dependency Injection** — техніка
*доставки* залежності: об'єкт отримує її ззовні (тут — через `init`), а не створює
сам. Можна мати DI без DIP (передати конкретний клас) і DIP без DI (шукати
реалізацію через service locator). У проєкті застосовано обоє.

### Заміна залежності без переписування коду

- Запуск з аргументом `-demo` (Edit Scheme → Run → Arguments Passed On Launch)
  підставляє `InMemoryTaskRepository` з готовими задачами. `TaskListViewModel` та
  `ContentView` лишаються без змін; змінюється лише рядок у `AppEnvironment`.
- У `#Preview` використано `AppEnvironment.makeDemoViewModel()`.
- У тестах підставляються `InMemoryTaskRepository`, ізольований `UserDefaults`
  (`UserDefaults(suiteName:)`) та фіксований годинник.

## 7. Перевірка на антипатерни

| Проблема | Де була (лаба 1 / перший коміт лаби 2) | Як виправлено |
|---|---|---|
| Надмірна відповідальність класу | `ContentView` одночасно малював екран, створював `TaskList`, наповнював його і друкував у консоль (`runDemoScenario`) | Розділено на View, ViewModel, Repository, Builder, Strategy |
| Пряме поєднання UI з даними | View напряму володіла моделлю й мутувала її | View бачить лише ViewModel; доступ до даних тільки через `TaskRepository` |
| Модель змішана з презентацією | `TaskList` був `ObservableObject` з `@Published` | `TaskList` став чистою моделлю; публікацію стану перейняла ViewModel |
| Приховані глобальні залежності | `Date()` у сценарії; `UserDefaults.standard` у типовому використанні | Усе «глобальне» читається лише в `AppEnvironment` і передається явно (`now`, `defaults`, `key`) |
| Дублювання/розкидані правила | Сортування за пріоритетом було зашите в `TaskList.pendingTasks` (лаба 1), а в першому коміті лаби 2 — у `ViewModel.refresh`; перевірка порожньої назви жила у ViewModel | Сортування — у стратегіях, валідація — в одному місці (`TaskItemBuilder.build`) |

### Що залишилось (свідомо)

- `TaskItem.describe()` і `Priority.displayName` містять рядки для екрана, тобто
  частину презентаційної логіки в моделі. Це залишок вимоги лаби 1 (протокол
  `Describable`). Для локалізації їх варто винести у ViewModel або форматер.
- `DateFormatter` створюється при кожному виклику `describe()`: не критично для
  такого обсягу даних, але потенційна оптимізація.
- `SortOption` потребує нового `case` для нової стратегії.

## 8. Як перевірити бізнес-логіку окремо від UI та реального сховища

Тести лежать у `TaskManagerTests/` (Swift Testing). ViewModel створюється з
`InMemoryTaskRepository` і фіксованим годинником, тому тестам не потрібні екран,
симулятор чи реальний `UserDefaults` застосунку:

- `TaskItemBuilderTests` — валідація назви, дедлайн від переданого часу;
- `SortStrategyTests` — порядок для кожної стратегії, включно з `nil`-дедлайнами;
- `RepositoryTests` — контракт «save → load» для обох реалізацій, пошкоджені дані,
  невідомий пріоритет;
- `TaskListViewModelTests` — додавання, перемикання, фільтр, сортування, помилки
  сховища (через підроблений репозиторій, що завжди падає);
- `NetworkingTests`, `ServerTasksViewModelTests`, `ImportFromServerTests` — мережевий шар
  із заглушкою транспорту й `MockTodoService`, без реальної мережі (див. [NETWORKING.md](NETWORKING.md)).

Як додати тестовий таргет, описано в README.

## 9. Відповідність «патерн / принцип — компонент — призначення»

| Патерн / принцип | Компонент | Призначення |
|---|---|---|
| MVVM | екрани / `TaskListViewModel` / `TaskList`, `TaskItem` | Розділення відображення, стану екранів і доменної логіки |
| Router | `AppRouter`, `TaskRoute`, `TaskModal` | Керована навігація окремо від View і ViewModel |
| Builder | `TaskItemBuilder` | Покрокове створення та валідація задачі |
| Adapter | `UserDefaultsTaskRepository` | Привести `UserDefaults` до інтерфейсу `TaskRepository` |
| Strategy | `TaskSortStrategy`, `PrioritySortStrategy`, `DueDateSortStrategy`, `TitleSortStrategy` | Взаємозамінні способи сортування |
| Observer (платформний) | `@Published` у `TaskListViewModel` | Автоматичне оновлення View |
| S (SRP) | `TaskList`, `TaskListViewModel`, `TaskRepository`, `TaskItemBuilder`, стратегії | Одна причина для змін на компонент |
| O (OCP) | `TaskSortStrategy`, `TaskRepository` | Додавання сортувань і сховищ без змін ViewModel |
| L (LSP) | `InMemoryTaskRepository`, `UserDefaultsTaskRepository` | Взаємозамінність за контрактом save → load |
| I (ISP) | `TaskRepository`, `TaskSortStrategy`, `Describable` | Малі протоколи без зайвих методів |
| D (DIP) | `TaskListViewModel` → `any TaskRepository`, `now` | Залежність від абстракцій, конкретику обирає `AppEnvironment` |
| DI | `TaskListViewModel.init`, `UserDefaultsTaskRepository.init` | Залежності приходять ззовні |
| Composition root | `AppEnvironment` | Єдине місце вибору реалізацій і читання глобальних джерел |
| Facade (спрощення) | `APIClient` | Один виклик `get` ховає складання запиту, статус, декодування, помилки |
| DTO | `RemoteTodo` | Форма даних сервера окремо від доменної моделі `TaskItem` |
| Test double / Stub | `MockTodoService`, `StubTransport` (тести) | Керовані відповіді замість реальної мережі |
| D (DIP), мережа | `ServerTasksViewModel` → `any TodoService`; `APIClient` → `any HTTPTransport` | Залежність від абстракцій; `URLSession` лише одна з реалізацій |

## 10. Навігація (практична робота 3)

Повний опис — у [NAVIGATION.md](NAVIGATION.md); тут — місце навігації в архітектурі.

- **Що додано:** `AppRouter` (`@Published` вкладка, стек `[TaskRoute]`, модальне вікно
  `TaskModal?`). `ContentView` стає коренем навігації: `TabView` → `NavigationStack(path:)`
  → `navigationDestination(for:)` та `sheet(item:)`.
- **Напрямок залежностей:** екрани → Router і ViewModel. Router не залежить ні від чого
  (крім типу `TaskItem.ID`); ViewModel не знає про Router.
- **Єдине джерело правди про дані** — `TaskListViewModel`. Маршрути несуть тільки `id`,
  тому після створення чи редагування всі екрани оновлюються самі.
- **Розширення:** новий екран = новий `case` у `TaskRoute`/`TaskModal` + гілка в
  `navigationDestination`/`sheet`; існуючі екрани не змінюються.
- **Тестування:** `AppRouterTests` перевіряють переходи без UI.

## 11. Мережевий шар (практична робота 4)

Повний опис — у [NETWORKING.md](NETWORKING.md); тут — місце мережі в архітектурі.

- **Що додано:** папка `Networking/` (`Endpoint`, `APIClient`, `HTTPTransport`, `NetworkError`, `RemoteTodo`,
  `TodoService`, `RemoteTodoService`, `MockTodoService`), `ServerTasksViewModel` зі станом `ImportState`,
  екран `ServerImportScreen`, модальний маршрут `TaskModal.importFromServer`.
- **Напрямок залежностей:** екран → `ServerTasksViewModel` → `TodoService` (протокол) ← `RemoteTodoService` → `APIClient`
  → `HTTPTransport` (протокол) ← `URLSession`. Вищі шари не знають про нижчі реалізації.
- **Окремий ViewModel для мережі.** `TaskListViewModel` залишився єдиним джерелом правди про *локальні* задачі
  і не отримав мережевих залежностей (SRP): стан завантаження — прохідний, його немає сенсу тримати разом із даними задач.
  Екран імпорту зустрічає обидва ViewModel: читає серверні дані з одного, а додає задачі через інший.
- **Імпорт проходить ту саму валідацію**, що й ручне створення: `RemoteTodo.makeDraft()` → `TaskListViewModel.create`
  → `TaskItemBuilder` → `TaskRepository`.
- **Розширення:** новий endpoint = новий метод у `TodoService`-подібному протоколі та `Endpoint`; `APIClient`
  і екрани не змінюються. Нове джерело даних = нова реалізація `TodoService`.
