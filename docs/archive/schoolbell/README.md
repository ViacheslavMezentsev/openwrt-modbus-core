# Архив разработки Школьника

[https://github.com/ViacheslavMezentsev/schoolbell](https://github.com/ViacheslavMezentsev/schoolbell)

Рабочий проект полностью перенесён в отдельный репозиторий. Этот архив не участвует в сборке, CI пакетов или публикации Pages.

- [snapshot.tar.gz](snapshot.tar.gz): original tracked sources, media, native helpers, prototypes, tests, application documentation and Pages; shared integration files are retained as context.
- [manifest.json](manifest.json): original paths, modes, SHA-256 and source commit 243a7ccad6aeb2499d3efd5d0c4cef9e822d393e.
- `retired`: removed from the active tree; `integration-context`: original shared files, whose maintained counterparts remain here.

Only tracked public files were captured. No local backups, device logs, credentials, build outputs or firmware downloads are included. Historical test results retain their original scope and are not new acceptance evidence.

Inspect with `tar -tzf docs/archive/schoolbell/snapshot.tar.gz`; extract only into a separate directory. Verify using `python3 scripts/test_archive.py`.

## Проверка переноса

08.11.2026: `make all check-site ci-core ci-demo` прошёл на хосте с Lua 5.1. Проверены SHA-256 всех 358 архивных файлов, отсутствие 309 выведенных файлов, core/demo IPK, выбор заданий CI и очистка старого демо при сборке сайта. Устройства и рабочие данные не изменялись; Pages не публиковались. Общие транспортные/I/O/релизные контракты и навык измерения часов остаются в ядре. Исторические ссылки и исключённые номера требований сохранены для прослеживаемости.
