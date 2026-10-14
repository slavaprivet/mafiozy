# Native site local session authority20

Статус: CPU TESTED, **не подключено к runtime**, нет server persistence.
Следующий source vertical slice временно уступил приоритет смерти NPC
по новому поручению пользователя через Художника19. Не потерять интеграцию.

Файлы: native_site_local_authority.mjs, test_native_site_local_authority.mjs,
test_native_site_local_authority_audit20.mjs в assets/maps/city_rebuild_v1.

Этот слой хранит owner/revision, одну роль HQ на семейство и operation receipts
только для одного явно заданного дома в текущей локальной сессии. Источник
передаёт текущего уполномоченного actor/faction и полные facts в callbacks.
Сам слой не выбирает охранников, не выводит смерть из отсутствия модели и
не подтверждает физический вход: это обязанности source adapter/catalog.

Capture и HQ проходят ранее проверенный native_site_control planner.
Перед единственным synchronous commit проверяются ожидаемые owner/defence/HQ
версии. Повтор operationId с тем же actor/payload возвращает прежнюю квитанцию;
с другим payload — conflict. При захвате чужого штаба старая HQ-role снимается
атомарно. Receipt не означает сетевую собственность: persistent:false.
После заполнения лимита256 квитанций новые операции отклоняются, старые не
удаляются ради повторного захвата. Dispose завершает сессию.

Независимый review нашёл callback reentrancy и изменения lifetime/прав между
чтениями. Root исправил: nested inspect/execute отклоняются; после facts
повторно сверяются local gate, dispose, actor/faction/canManage. Исходные
4 и независимые4 regression — **8/8 PASS**, последний root прогон200.8мс CPU.

Не проверены runtime/source roster/E/бой/сохранение/reload/LIVE/FPS.
Следующее подключение описано в NATIVE_SITE_SOURCE20_INTEGRATION_PLAN.md:
реальный oldtown001 catalog/feet + private source roster + existing E context.
19 разрешил leila/marat по stable specialistId, только реально существующих
eligible бойцов, обычный маршрут без teleport и без смены прежних владений.
Missing/unhydrated actor и незавершённое назначение охраны дают unknown.
Localhost сам по себе не authority: explicit QA gate и исключение Telegram,
Steam, real-account/authenticated путей обязательны перед runtime подключением.
