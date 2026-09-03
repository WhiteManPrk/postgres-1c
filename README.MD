***

# PostgreSQL 1C 🐘

[![Docker Pulls](https://img.shields.io/docker/pulls/whitemanprk/postgres-1c)](https://hub.docker.com/r/whitemanprk/postgres-1c)
[![Docker Image Size](https://img.shields.io/docker/image-size/whitemanprk/postgres-1c/latest)](https://hub.docker.com/r/whitemanprk/postgres-1c)
[![PostgreSQL Version](https://img.shields.io/badge/PostgreSQL-16,17,18-blue)](https://www.postgresql.org/)


**Контейнерный Docker-образ PostgreSQL для 1С:Предприятие с автоматизацией сборки из официальных deb‑пакетов и поддержкой оптимизированных сценариев деплоя.**


***

## 🎯 Особенности

- ✅ **Сборка из официальных deb-пакетов PostgreSQL для 1С**
- ✅ **Мультиверсионность** — Сборка под любую поддерживаемую 1С версию PostgreSQL (`PG_MAJOR`)
- ✅ **Совместимость с официальным postgres и 1С** — стандартные переменные окружения: `POSTGRES_USER`, `POSTGRES_DB`, ...; init‑скрипты, healthcheck, сигналы завершения, локализация
- ✅ **Автоматизация** — автоматическое создание прикладных ролей (`DB_USER`, `DB_PASS`) и баз данных (`DB_NAME`) через переменные окружения при инициализации
- ✅ **Пользовательские initdb‑скрипты** — любые *.sh/*.sql/*.sql.gz в `/initdb` будут выполнены при первом старте кластера
- ✅ **Гибкая сетевая настройка** — переменные `PG_ALLOWED_HOSTS`, `PG_HBA_METHOD`, `PG_LISTEN_ADDRESSES` используются через свой initdb-скрипт (пример ниже)
- ✅ **Локализация по умолчанию** — ru_RU.UTF-8 для окружения и кластера
- ✅ **Healthcheck и корректное завершение по стандарту Docker**

***

## 📦 Получение deb‑архивов

Скачайте с портала поддержки 1С официальные deb‑архивы:

- **Дистрибутив СУБД PostgreSQL для Linux x86 (64-bit)**
- **Зависимости postgres для Debian 12 x86_64**

Распределите deb‑файлы по каталогам:

- `distr/<версия>/core/` — основные пакеты (postgresql‑16, postgresql‑client‑16, libpq5 и др.)
- `distr/<версия>/libs/` — все дополнительные зависимости

***

## 🛠️ Сборка образа

```bash
docker build -t postgres-1c:16 --build-arg PG_MAJOR=16 .
```


***

## 🚀 Быстрый старт через Compose

```yaml
services:
  pg1c:
    build:
      context: .                 # Указывает на текущую директорию, где лежат Dockerfile и папка distr/
      args:
        PG_MAJOR: 18             # Версия(изменить под необходимую)
    image: local/postgres-1c:18  # Имя, которое получит собранный образ 
    container_name: pg1c
    restart: unless-stopped
    stop_grace_period: 60s
    ports:
      - "${PG_PORT:-5432}:5432"
    environment:
      #POSTGRES_USER: "${POSTGRES_USER:-postgres}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-secret}"
      #POSTGRES_DB: "${POSTGRES_DB:-postgres}"
      #LANG: "${LANG:-ru_RU.UTF-8}"
      #LC_ALL: "${LC_ALL:-ru_RU.UTF-8}"
      #TZ: "${TZ:-Asia/Tomsk}"
      POSTGRES_INITDB_ARGS: "${POSTGRES_INITDB_ARGS:---encoding=UTF8 --locale=ru_RU.UTF-8}"
      #DB_USER: "${DB_USER:-app}"
      #DB_PASS: "${DB_PASS:-appPass123}"
      #DB_NAME: "${DB_NAME:-appdb}"
    volumes:
      - pg1c-data:/var/lib/postgresql/data
      # для 18 версии
      #- pg1c-data:/var/lib/postgresql/18/data
      - ./initdb:/docker-entrypoint-initdb.d:ro

volumes:
 pg1c-data:
   driver: local
```

> Рекомендуется использовать параметры из `.env.example` и монтировать папку данных и initdb-скриптов.

***

## 📑 Пример .env

```env
PG_PORT=5432

POSTGRES_PASSWORD=postgrespass

DB_USER=user1
DB_PASS=pass1
DB_NAME=test1,test2,test3

POSTGRES_INITDB_ARGS=--encoding=UTF8 --locale=ru_RU.UTF-8
TZ=Asia/Tomsk
```


***

## 🌐 Пример скрипта для гибкой сетевой настройки

Контейнер **не обрабатывает** переменные типа `PG_ALLOWED_HOSTS`, `PG_HBA_METHOD`, `PG_LISTEN_ADDRESSES` сам по себе!
Для настройки pg_hba.conf и listen_addresses используйте пользовательский скрипт в `initdb/`, например:

```bash
#!/bin/bash
PG_HBA="${PGDATA}/pg_hba.conf"
PG_CONF="${PGDATA}/postgresql.conf"

if [[ -n "${PG_LISTEN_ADDRESSES}" ]]; then
  sed -i "s/^#listen_addresses =.*/listen_addresses = '${PG_LISTEN_ADDRESSES}'/" "$PG_CONF"
fi

if [[ -n "${PG_ALLOWED_HOSTS}" ]] && [[ -n "${PG_HBA_METHOD}" ]]; then
  IFS=',' read -ra HOSTS <<< "${PG_ALLOWED_HOSTS}"
  for HOST in "${HOSTS[@]}"; do
    echo "host    all    all    ${HOST}    ${PG_HBA_METHOD}" >> "$PG_HBA"
  done
fi
```


***

## 🏗️ Пользовательские initdb‑скрипты

Файлы из каталога `initdb/` (sh, sql, архивы) — автоматическое выполнение при инициализации кластера.

***

## 📋 Сборка

- Debian 12 Bookworm (base image)
- Официальные deb‑пакеты PostgreSQL для 1С — пользователь скачивает и добавляет сам

***

***

## ℹ️ Важно: стандартная эксплуатация и настройка

Этот контейнер реализует **стандартный запуск PostgreSQL** с минимально необходимыми изменениями для поддержки модификации 1С. После первого запуска СУБД **требуется обязательная настройка** под ваши задачи и аппаратные ресурсы — как и для любого продакшн-деплоя PostgreSQL.

- Проверьте и оптимизируйте основные параметры кластера под реальные нагрузки и типовые задачи.
- Не забудьте настроить доступы:
    - Адреса, с которых разрешено подключение (`pg_hba.conf` — можно использовать переменные `PG_ALLOWED_HOSTS`, `PG_HBA_METHOD` через initdb-скрипт).
    - Основной конфиг для слушающих адресов (`listen_addresses` через переменную `PG_LISTEN_ADDRESSES` или явно).
- Для безопасности ограничивайте внешний доступ только необходимыми хостами/подсетями, используйте современные методы аутентификации.

> Корректная эксплуатация и безопасная настройка PostgreSQL полностью лежит на администраторе/девопсе. Точно следуйте лучшим практикам настройки 1С/СУБД и документации вашей инфраструктуры.

***

## 📝 Лицензия

**В репозитории отсутствуют** deb‑архивы PostgreSQL 1С. Распространение и лицензия только через 1С.

***
