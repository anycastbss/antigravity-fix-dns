<div align="center">

# 🚀 Antigravity & AI Bypass for macOS (Belarus & CIS Edition)

[![Platform](https://img.shields.io/badge/Platform-macOS%20(Intel%20%7C%20Apple%20Silicon)-black?style=flat-square&logo=apple)](https://apple.com)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-blue?style=flat-square&logo=gnubash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Tested On](https://img.shields.io/badge/Tested%20on-Antigravity%202.0%20%7C%20IDE%20%7C%20CLI-orange?style=flat-square)](https://antigravity.google)

**Комплексное решение для стабильной работы Google Antigravity 2.0, Antigravity IDE, CLI (`agy`), Gemini, Claude и OpenAI в Беларуси и странах с региональными ограничениями.**

[Быстрый старт](#-быстрая-установка-в-одну-строку) • [Как это устроено](#-как-это-устроено-2-уровня-защиты) • [Команды CLI](#-справочник-команд-cli) • [Диагностика Doctor](#-режим-диагностики-agy-dns-doctor) • [Бенчмарк](#-бенчмарк-smart-dns) • [FAQ](#-частые-вопросы-faq)

</div>

---

## ⚡ Быстрая установка в одну строку

Откройте Терминал на Mac и выполните:

```bash
curl -fsSL https://raw.githubusercontent.com/anycastbss/antigravity-fix-dns/main/install.sh | bash
```

Установщик создаст системную команду **`agy-dns`**, настроит окружение и предложит сразу включить защиту.

---

## 💡 Как это устроено: 2 уровня защиты

Блокировка сервисов Google AI в Беларуси и РФ носит гибридный характер. Инструмент устраняет оба барьера:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        macOS (Minsk, Belarus)                          │
│                                                                        │
│  Antigravity IDE ──► [agy-unlock daemon] (Снимает блок Google-аккаунта)│
│       │                                                                │
│       ▼                                                                │
│  [IPv6 Leak Shield] (Блокирует прямую утечку белорусского IPv6)       │
│       │                                                                │
│       ├───────────────────────────────┬────────────────────────────────┤
│       ▼                               ▼                                │
│   Обычный трафик (99%)          AI-запросы (1%)                        │
│   YouTube, GitHub, TG           generativelanguage.googleapis.com      │
│   Локальные сайты BY            alkalimakersuite-pa.googleapis.com     │
│       │                         api.anthropic.com                      │
│       │                         api.openai.com                         │
│       ▼                               │                                │
│   Провайдер A1 (прямой)               ▼                                │
│   (100% скорость, 0 ms пинг)    Smart DNS + SNI-шлюз (xbox-dns.ru)     │
│                                       │                                │
│                                       ▼                                │
│                                 Google Cloud / AI (Доступ разрешен!)   │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Сетевой уровень (Smart DNS + Защита от утечек IPv6)**:
   * **Smart DNS ([xbox-dns.ru](https://xbox-dns.ru))**: в прокси направляются только 1% трафика к AI-моделям. Все остальные сайты работают напрямую на максимальной скорости вашего тарифа.
   * **IPv6 Leak Shield**: белорусские провайдеры (A1, ByFly, МТС) выдают нативные IPv6-адреса. Механизм *Happy Eyeballs* macOS отправляет запросы к Google по IPv6 мимо Smart DNS. Скрипт безопасно отключает IPv6 во время работы, исключая блокировку по геолокации.
2. **Уровень аккаунта Google (`agy-unlock`)**:
   * В Antigravity встроена проверка региона самого профиля Google.
   * Инструмент интегрирован с утилитой `agy-unlock`: автоматически патчит аргументы запуска языкового сервера (`language_server` / `main.js`) и контролирует фоновый системный демон автопатча при обновлениях.

---

## 💻 Справочник команд CLI

После установки вам доступна глобальная команда `agy-dns` из любой папки:

| Команда | Описание |
| :--- | :--- |
| `agy-dns on` | Включить полный комплекс (Smart DNS + защита от IPv6 leak + agy-unlock) |
| `agy-dns off` | Отключить обход и вернуть стандартные сетевые настройки провайдера |
| `agy-dns status` | Показать текущий статус DNS, статус IPv6-утечки, IP и состояние демона |
| `agy-dns test` | Замерить задержку и проверить HTTP-доступность Gemini, Claude, OpenAI |
| `agy-dns doctor` | **Глубокая самодиагностика 6 уровней системы** |
| `agy-dns benchmark` | **Замерить скорость и RTT отклика серверов Smart DNS** |
| `agy-dns unlock` | Открыть интерактивный дашборд `agy-unlock` |
| `agy-dns profile` | Открыть профиль шифрованного DNS-over-HTTPS (`.mobileconfig`) |
| `agy-dns flush` | Очистить системный кеш DNS (`mDNSResponder`) |
| `agy-dns` | Запустить удобное интерактивное меню с номерами действий |

---

## 🩺 Режим диагностики: `agy-dns doctor`

Команда `agy-dns doctor` проверяет 6 критических уровней системы:
1. **Процессы Antigravity** (IDE, CLI, языковой сервер).
2. **Статус `agy-unlock`** и активность фонового демона автопатча.
3. **Smart DNS-резолвинг** (проверяет, что `generativelanguage` идет в прокси).
4. **IPv6 Leak Check** (проверяет наличие открытых публичных IPv6-адресов).
5. **Сторонние конфликты** (проверяет переменные `HTTP_PROXY`, системные прокси, VPN).
6. **SSL/TLS Validation** (проверяет подлинность сертификатов Google Trust Services, исключая провайдерский MITM).

---

## 🏎 Бенчмарк Smart DNS: `agy-dns benchmark`

Замеряет точное время отклика (RTT в миллисекундах) до всех доступных шлюзов в вашем регионе:
```text
▶ Бенчмарк серверов Smart DNS (поиск наименьшей задержки)
Сервер                   IP-адрес           Отклик (RTT)   Smart DNS
------------------------------------------------------------------
Xbox DNS Primary         111.88.96.54       13 ms          Да
Xbox DNS Secondary       111.88.96.55       16 ms          Да
Cloudflare (Эталон)      1.1.1.1            19 ms          Нет
Google (Эталон)          8.8.8.8            33 ms          Нет
```

---

## 🛡 Аппаратный шифрованный DNS (DoH Profile)

Если ваш интернет-провайдер перехватывает порт 53 (UDP), установите системный профиль Apple:
```bash
agy-dns profile
```
Откройте **«Системные настройки» → «Конфиденциальность и безопасность» → «Профили»** и нажмите **Установить**.
После этого все DNS-запросы macOS будут зашифрованы по протоколу TLS 1.3 через `https://xbox-dns.ru/dns-query`.

---

## ❓ Частые вопросы (FAQ)

<details>
<summary><b>1. Падает ли скорость скачивания и пинг в играх?</b></summary>
Нет. Smart DNS — это не тяжелый VPN. Через европейский шлюз направляются только единичные HTTPS-запросы к заблокированным AI-эндпоинтам (Gemini, Claude, OpenAI). Весь остальной трафик (YouTube в 4K, Telegram, торренты, игры) идет напрямую со 100% скоростью вашего провайдера.
</details>

<details>
<summary><b>2. Что делать, если Antigravity обновилась и снова выдает ошибку региона?</b></summary>
Фоновый демон обычно возвращает патч автоматически за секунды. Если этого не произошло, просто запустите:
```bash
agy-dns on
```
</details>

<details>
<summary><b>3. Как полностью удалить инструмент?</b></summary>
Верните стандартную сеть и удалите файлы:
```bash
agy-dns off
rm -rf ~/.antigravity-fix-dns ~/.local/bin/agy-dns
```
</details>

---

## 🤝 Благодарности
- Команде [xbox-dns.ru](https://xbox-dns.ru) за создание серверов Smart DNS и бинарника `agy-unlock`.
- Проекту Google DeepMind за потрясающую среду [Google Antigravity](https://antigravity.google).

---

## 📄 Лицензия

Проект распространяется под лицензией [MIT](LICENSE).
