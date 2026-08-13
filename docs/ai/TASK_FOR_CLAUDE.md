# TASK_FOR_CLAUDE

Before implementing or expanding a 3D feature, read
`docs/ai/OPTIMIZATION_MEMORY.md` and keep its quality contract and validation
checklist in the task acceptance criteria.

Before changing gangs, bosses, NPC empires, diplomacy, criminal businesses,
property guards or raids, read `docs/ai/GANG_SYSTEM_MEMORY.md`. If the task also
changes 3D presentation, both memory files are mandatory. Update the relevant
memory in the same change whenever an authoritative contract or regression
suite changes.

(Шаблон. Заполняет ChatGPT/пользователь перед тем как принести задачу Claude Code.
Перед написанием задачи прочитать ARCHITECTURE.md в корне проекта — там реальная
архитектура, системы координат и грабли. Не придумывать функции/переменные,
которых там нет — если непонятно, есть ли что-то — писать "проверить, существует
ли X", а не утверждать, что существует.)

## Цель
...

## Текущая проблема
...

## Файлы
...

## Что изучить
(конкретные функции/переменные из ARCHITECTURE.md / world_index.txt, которые
нужно прочитать в РЕАЛЬНОМ коде перед правкой)
...

## Что изменить
...

## Что нельзя менять
- не переписывать world.html/mafiozi_bot.py целиком
- не создавать параллельные системы, если уже есть существующая (сверить с ARCHITECTURE.md)
- не менять БД/серверную архитектуру/WebSocket-протокол без явного разрешения
- не трогать Steam-версию
...

## Проверки
- node --check / python -m py_compile
- живой прогон в превью (не только чтение кода)
- git diff --stat
...

## Commit message
...
