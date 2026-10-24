# Сайт проекта и демо schoolbell

[English](README.en.md)

Исходники: landing RU/EN в site/, интерфейс демо строится из packages/schoolbell/router-page/root. Никаких отдельных копий макета: build-site.py подставляет demo endpoints и локальную модель site/demo.js. Тестовая мелодия копируется вместе с NOTICE; авторство и исходные SHA256 сохраняются в packages/schoolbell/media.

```sh
make check-site
python3 -m http.server 8769 --bind 127.0.0.1 --directory out/site
```

Откройте http://localhost:8769/. Сборка требует Python3 и Node.js (проверки модели); внешних npm-зависимостей нет. Сайт не требует backend.

## Границы демо

- Данные только в localStorage этого сайта (ключ openwrt-schoolbell-public-demo-v1); при запрете storage — в памяти вкладки.
- Сохранение, предпросмотр, журнал последних 80 событий и зона моделируются в браузере. Серверная строгая валидация и crash guarantees не эмулируются полностью.
- Подключения к роутеру нет, аппаратная кнопка отключена. Browser test.mp3 звучит только по нажатию; автоматических звонков нет.
- Сброс удаляет только данные демо после подтверждения. Персональные конфигурации сюда загружать не нужно.

## Публикация владельцем

После merge и успешного CI точного main: Settings → Pages → Build and deployment → Source: GitHub Actions. Затем Actions → GitHub Pages → Run workflow на main. Workflow намеренно ручной и не запускается при push, чтобы публикация оставалась отдельным решением владельца. Ожидаемый адрес после успешного deployment: https://viacheslavmezentsev.github.io/openwrt-modbus-core/ . Пока workflow не завершился, адрес не считается опубликованным.

Используется стандартный [workflow GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages): configure-pages, upload-pages-artifact и deploy-pages. CI проверяет сборку и локальную модель; фотографии реального стенда и телеметрия в сайт не включаются.
