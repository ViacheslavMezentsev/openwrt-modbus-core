# Подписанный манифест и API проверки релизов

[English](SIGNED_RELEASES.en.md) · [Общий контракт](RELEASE_UPDATES.md)

26.10.2026. Контракт: core 6.12 / ревизия 1.35, schoolbell 4.8 / ревизия 1.55. Изолированная host-модель описана ниже (core 1.36). Реальные ключи, криптография, сеть и установка не подключены.

## Поставка и несколько платформ

В GitHub Release, в разделе Assets, рядом находятся IPK и пары метаданных для каждой платформы. Пример раскладки, не утверждение о существующем релизе:

```text
modbus-schoolbell_5.1.2_all.ipk
modbus-rover_1.0.0_all.ipk
modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk
release-openwrt-19.07.9-ramips-mt76x8.json
release-openwrt-19.07.9-ramips-mt76x8.sig
release-<другой-проверенный-профиль>.json
release-<другой-проверенный-профиль>.sig
```

Эти файлы публикует сборщик релиза; не Pages и не обязательно Git. IPK остаётся `<Package>_<Version>_<Architecture>.ipk`. Если разные профили имеют разные байты одной версии/архитектуры, asset называется `<Package>_<Version>_<Architecture>.<profile>.ipk`. Внутренние control-поля не меняются. Точное имя asset берётся из манифеста. Одинаковые байты могут использовать один asset несколькими профилями. Внутри профиля переиздание Package/version/architecture с другим хешем запрещено: новая patch-версия.

Одна пара json/sig на профиль в релизе описывает несколько независимых модулей. Общие зависимости перечислены один раз. Выбирается только запрошенный модуль и его транзитивные зависимости; другие модули не устанавливаются. Поддержка старого и нового OpenWrt может идти параллельно. Отсутствие старого профиля в очередном релизе не означает прекращения его поддержки или завершения поиска. Номер major приложения не кодирует OpenWrt: предпочтительна одна совместимая линия Школьника, при необходимости допустимы независимые мажорные линии.

Profile — зарегистрированный идентификатор точного platform-набора, а не только версия OpenWrt. Различающимся обязательным ABI назначаются разные профили. Проверяется содержимое platform, имя файла не доказывает совместимость. После обновления firmware результат прежней проверки теряет пригодность; начинается новый выбор профиля, без автоматической миграции пакетов. Формат v1 — только IPK/opkg; другой формат установки требует отдельного профиля/контракта и пока отклоняется.

## Подпись и JSON

Manifest — UTF-8 JSON без BOM, максимум 65536 байт вместе с пробелами/LF. Подпись **pure Ed25519 RFC8032** над точными байтами файла, без Ed25519ph, SSH-обёртки и повторной сериализации. Никакой канонизации на устройстве: изменение LF/CRLF/пробела меняет сообщение. Сборщик формирует воспроизводимые байты.

Файл `.sig` — JSON до 512 байт, ровно три строковых поля:

```json
{"algorithm":"ed25519","key_id":"<64 lowercase hex>","signature":"<128 lowercase hex>"}
```

Пример показывает форму, не настоящую подпись. key_id=SHA256 от 32 сырых байтов публичного ключа, signature=64 сырых байта подписи в lowercase hex. Ключ заранее установлен с разрешёнными repository/publisher; ключ из релиза не принимается. Неизвестный ключ/алгоритм и неверная подпись — отказ. В v1 смена/отзыв ключа только отдельной административной процедурой. Target-verifier и доставка trust store ещё выбираются; Ed25519 самостоятельно не реализуется.

Сначала ограничение размера и разбор sig, затем проверка исходных байтов manifest, затем его строгая схема. В обоих JSON запрещены duplicate keys, неизвестные поля, неверный UTF-8, BOM, NaN/Infinity. Глубина до 8. Целые — 0…2147483647, десятичные без экспоненты/дроби; размеры файлов положительные. Строки без NUL/control characters. Поля ниже обязательны, null допустим только явно. Все пределы строк — байты UTF-8.

## Манифест v1

| Поле | Тип/смысл |
| --- | --- |
| format | точная строка `openwrt-extension-release/1` |
| repository | owner/repo до 200 байт, совпадает с регистрацией источника |
| tag | tag_name выбранного Release, до 256 байт; не версия модуля |
| source_commit | 40 lowercase hex исходного Git SHA-1 |
| platform | объект ниже |
| components | 1–64 независимо обновляемых компонента |
| packages | 1–64 IPK модулей и зависимостей |

platform имеет ровно: profile (1–96 ASCII `[a-z0-9][a-z0-9._-]*`), package_format=`ipk`, openwrt (до32), target (до64), architecture (до64), libc={name,version} (до 64 каждая), lua (ABI до16), kernel_abi (до128 или null при отсутствии kmod), firmware (до 64 уникальных {name,version} встроенных пакетов). Для kmod kernel_abi обязателен и точен. Firmware-зависимости не заменяются комплектом. Версии/platform сравниваются с проверенным локальным состоянием, не браузерными параметрами. Profile совпадает с частью имени json/sig.

Каждый component имеет ровно:

| Поле | Тип/смысл |
| --- | --- |
| publisher, name | 1–64 ASCII `[A-Za-z0-9][A-Za-z0-9_-]*`; уникальная пара |
| package | root Package из packages; разные компоненты не делят один root |
| version_scheme | `semver3` или `opkg` |
| upgrade_from | 1–16 непересекающихся {min_inclusive,max_exclusive}; верхняя граница может быть null |
| requires_core_api | поддерживаемый идентификатор до 64 байт или null; неизвестный несовместим |
| data_policy | {action,rollback}; action=preserve/migrate, rollback=package_only/restore_backup |

Версия компонента — version его root package, без отдельного дублирующего поля. Semver3: три числа 0…2147483647 без ведущих нулей кроме 0, через точки, без suffix/build metadata. Интервалы upgrade_from используют version_scheme, min<max. opkg не сравнивается как SemVer. Schoolbell использует semver3. Межмажорный переход возможен только по upgrade_from и подтверждённой миграции. Разрешённый переход в metadata не доказывает готовность выполнения миграции. Установка отсутствующего модуля вне этого API.

Каждый package имеет ровно:

| Поле | Тип/смысл |
| --- | --- |
| name | 1–128 ASCII `[a-z0-9][a-z0-9+.-]*`; уникальный Package |
| version | opkg Version, строка 1–128байт |
| architecture | 1–64байта; all либо совместимая архитектура |
| asset | basename 1–192 ASCII `[A-Za-z0-9][A-Za-z0-9._+-]*`, `.ipk`, без slash/backslash/`..`; уникальное имя |
| bytes | положительный целый размер IPK |
| sha256 | 64 lowercase hex |
| depends | до64 {name,op,version}; op=any/eq/ge/gt/le/lt; any требует version=null, остальные строку opkg Version |

firmware/depends.name и firmware.version используют те же ограничения, что packages.name/version. Граф замкнут через packages или firmware; одно имя не объявляется в обоих. Циклы запрещены. Depends — конъюнкция: все условия выполняются. Альтернативы/виртуальные Provides/Conflicts, не представимые v1, не упрощаются: неподдержанный пакет отклоняется. При подготовке нормализованные Depends, Package/Version/Architecture и размер/хеш сверяются с реальным IPK. Обнаружение ещё не скачивает IPK; его кандидат проверен по подписанным метаданным.

Перед изменением общей библиотеки проверяются обратные зависимости всех установленных пакетов. Нельзя сломать rover ради обновления schoolbell: показывается dependency_conflict, без удаления соседнего пакета/force-depends. Совместимая установленная зависимость сохраняется. Дубли компонентов/Package/asset в manifest — invalid_manifest; одна версия/профиль с другим SHA между релизами — release_conflict. Манифест не содержит команд/скриптов/произвольных URL. Хуки IPK и безопасность распаковки проверяются отдельно при admission.

## API сервиса и статусы

Это логический API, не ещё невыбранные HTTP/ubus endpoints. component — зарегистрированная строка publisher/name. Браузер не задаёт URL/repository/profile/key/команды. Check/configure требуют администратора и защиты запроса; status — авторизованного читателя. Конкретный транспорт/ACL впереди.

| Операция | Ответ/поведение |
| --- | --- |
| check(component) | немедленно `{accepted,operation_id,state,error}`; старт асинхронной проверки или присоединение к текущей для того же component; другой component получает busy без очереди |
| status(component) | сохранённый снимок без сети; polling UI не перезапускает проверку |
| configure(component,background_checks) | boolean; `{ok,background_checks,error}`; false запрещает новые фоновые попытки, текущая может закончиться |

component — строка `publisher/name` зарегистрированного компонента. operation_id — 32 lowercase hex. Успех check: accepted=true/state=checking/error=null; отказ: accepted=false/state=idle/operation_id=null/error=код. Успех configure: ok=true/error=null; отказ ok=false/error=код и прежнее значение политики. ID не является полномочием. Обрыв/повтор check не создаёт вторую текущую операцию; незавершённая после рестарта автоматически не возобновляется.

status содержит: component, state (`idle/checking/complete/failed`), operation_id (32 hex/null), result (`update_available/up_to_date/incompatible/incomplete`/null), error (код/null), installed_version (строка/null), candidate (объект/null), scan_complete (boolean), fresh (boolean), age_seconds (целое/null), retry_after_seconds (целое/null), background_checks (boolean), last_success (предыдущий успешный снимок без собственного last_success либо null). Для неизвестного компонента state=failed/error=unknown_component, остальные недоступные значения null, boolean=false. У snapshot нет произвольного поля raw GitHub payload.

candidate содержит ровно candidate_id, version, profile, manifest_sha256, repository, tag, signature_verified=true. candidate_id — SHA256 точных байтов manifest, двоеточие, component; не разрешение установки. Он привязан к компоненту/профилю/манифесту и повторно проверяется при подготовке. Непроверенные данные не становятся candidate.

Новая попытка очищает текущие result/error/candidate, state=checking, fresh=false, scan_complete=false; прежний успех остаётся отдельно в last_success. Idle/result=null — до первого запуска. Failed/result=null — нет пригодного результата попытки. Complete означает завершённый алгоритм, не установку. Incomplete всегда scan_complete=false. Найденный проверенный кандидат при неполном поиске допускает update_available/scan_complete=false с причиной; UI не называет его самым новым. Up_to_date допускается только при полном определённом поиске без более новой совместимой версии и без несовместимых новых вариантов; последние дают incompatible. Отсутствие любых достоверных metadata компонента — incomplete/no_matching_manifest, не up_to_date. Пустое старое/чужое release само не завершает поиск; потенциальный подходящий выпуск с отсутствующей/битой парой metadata делает результат неполным.

Коды: unknown_component, unauthorized, busy, network, dns, tls, clock_untrusted, rate_limited, timeout, response_too_large, invalid_manifest, unknown_key, bad_signature, release_conflict, unsupported_format, no_matching_manifest, incompatible_platform, dependency_conflict, internal. При пригодном кандидате ошибка другой части поиска сохраняется в error и scan_complete=false. Точная типизация ошибок backend будет проверена отдельными тестами.

Age — от завершения последней попытки по монотонным часам. Fresh=true только для complete, возрастом менее 86400 с того же boot/process и при неизменных установленных пакетах/профиле/ключах. После рестарта age=null/fresh=false; после начала проверки age=null. Last_success содержит пересчитанные свежесть/возраст по тем же правилам, не выдаётся за успех новой попытки. После смены пакетов даже свежие по времени кандидаты перепроверяются. Недостоверный UTC не используется для возраста.

## GitHub, лимиты и неполный поиск

GET `/repos/{owner}/{repo}/releases?per_page=10`, затем Link next того же endpoint/repository, не `/latest`. Публичный доступ без PAT и cookies LuCI. Draft/prerelease исключены. Ищется точная пара release-<local-profile>.json/.sig. URL берутся из API только после проверки источника; названия/даты релизов не определяют порядок версий. Выбирается наибольшая поддерживаемая версия запрошенного компонента для локального профиля, а не последний релиз всего репозитория.

| Лимит | Значение |
| --- | --- |
| Manifest / signature | 65536 / 512 байт |
| Components / packages | до 64 каждого |
| JSON depth | 8 |
| Список релизов | 3 страницы по 10, до 30 релизов |
| Ответ списка | 262144 байта |
| Общий срок проверки | 60000 мс монотонных, включая DNS/TLS/redirect/metadata |
| Параллелизм | одна проверка, один HTTP запрос за раз |
| Фоновые попытки | не чаще 86400 с, без догоняющего шторма |

Реальный прочитанный размер ограничивается независимо от Content-Length. V1 запрашивает identity encoding; неожиданный compression отклоняется. Пары metadata обрабатываются последовательно с освобождением памяти, не хранятся все в Lua. До 30 пар могут быть прочитаны в рамках общего срока. Наличие Link next после третьей страницы, timeout/overflow/неполные assets не даёт up_to_date. Внутри проверки не повторяется неудачный HTTP; новый запуск требует соблюдения backoff. ETag/304 использует только полный ограниченный кэш того же URL с повторной проверкой пригодности; без кэша — incomplete.

HTTPS не ослабляется из-за часов. Redirect не меняет registered repository/profile; точный CDN allowlist, число переходов, защита private/link-local/DNS rebinding, HTTP backend, parser RAM и backoff при неверном UTC ещё выбираются перед системной реализацией. Без этих ограничений downloader не допускается. Retry-After/rate limit обязательны, ручная кнопка их не обходит. Новое время/NTP/сеть не настраиваются.

## Проверки и остающиеся границы

Core TC-150–157 плановые: Ed25519/изменённые байты; схема/границы; несколько модулей; разные платформы/reverse-dependencies; API/повторы/ACL; лимиты/кэш/неполнота; имена assets/control; старый ключ/clock/replay. RFC8032 содержит внешние контрольные векторы; target-verifier ещё не проверен.

Не реализуются установка, генерация ключей, ротация/revocation, anti-replay, persistent-cache и wire transport. Нужно выбрать системный verifier/HTTPS, ACL, RAM/tmpfs и flash-бюджет, redirect/backoff, точный opkg comparator и состояние после reboot. До этого допустима отдельная изолированная модель, а не запуск updater на роутере.

Источники: [GitHub Releases](https://docs.github.com/en/rest/releases/releases), [REST best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api), [RFC8032](https://www.rfc-editor.org/rfc/rfc8032).

## Изолированная модель на хосте (ТЗ 1.36)

Запуск: `make test-release-discovery`, только стандартная библиотека Python. Проверка включена в runner core/all. `scripts/release_manifest.py` проверяет байты, envelope подписи, схему, scope доверенного ключа, версии и замыкание выбранного компонента с обратными зависимостями. `scripts/release_discovery.py` предоставляет check/status/configure, кооперативный step и доверенный replace_context. Возвращаемые снимки — копии.

Конструктор Discovery принимает registry, local, keys, fetch, монотонные часы в миллисекундах, verifier и opkg comparator. Local содержит platform, все installed-пакеты с полными depends, core_apis и разрешённые кортежи migrations. Это доверенные данные адаптера, не параметры браузера. Verifier получает сырые байты публичного ключа, исходного manifest и подписи и должен вернуть именно True. Comparator opkg возвращает -1/0/1; тестовая числовая подмена не реализует реальный порядок opkg.

Fetch получает Request(repository, kind, page либо tag/asset, limit, deadline_ms) и возвращает Response(body bytes, status, next_page, encoding, error, retry_after_ms). Kind — list или asset; запросов IPK нет. Список — JSON в форме записей GitHub; next_page уже нормализован адаптером для того же источника. Сырые URL модель не принимает. Будущий транспорт обязан проверять URL/redirect/Link, ограничивать поток байтов и соблюдать срок. Проверка после возврата callback не прерывает блокирующий реальный вызов. Step выполняет максимум один подменяемый fetch; check/status сеть не вызывают.

Отсутствие профильной пары консервативно делает поиск неполным, но не останавливает просмотр старых релизов. HTTP-кэша нет: bare 304 не доказывает актуальность. Ошибка сети завершает попытку; ошибка схемы/подписи отдельной пары позволяет продолжить поиск. Ранее проверенный кандидат может остаться с scan_complete=false, конфликт переиздания его отменяет. Проверка подписи, завершившаяся после deadline, не публикует кандидата. Backoff общий для repository; при подменённом rate limit без заголовка используется резерв 60 с — это политика модели, не утверждённый production backoff. Фоновое расписание моделируется явным check(background=True), службы-планировщика нет.

32 теста покрывают схему, подменяемую подпись, зависимости, API и границы поиска. Тестовая подпись намеренно НЕ Ed25519. Реальные crypto/TLS/GitHub, системная аутентификация, чтение IPK, установка и бюджет памяти устройства не подтверждены. Boolean полномочий моделирует уже проверенного вызывающего, а не механизм входа. Состояние не сохраняется: новый объект начинает idle; replace_context отменяет работу и инвалидирует кандидатов при смене пакетов/профиля/ключей. Постоянный anti-replay и recovery остаются открытыми.
