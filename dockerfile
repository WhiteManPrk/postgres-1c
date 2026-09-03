# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

ARG PG_MAJOR
ENV PG_MAJOR=${PG_MAJOR} \
    LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8 \
    PGDATA=/var/lib/postgresql/data \
    PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=ru_RU.UTF-8" \
    POSTGRES_PASSWORD="" \
    POSTGRES_USER=postgres \
    POSTGRES_DB=postgres

RUN set -eux; \
    if [ -z "$PG_MAJOR" ]; then \
        echo "ERROR! You MUST pass --build-arg PG_MAJOR=<number>" >&2; exit 101; \
    fi; \
    groupadd -r postgres --gid 999; \
    useradd -r -g postgres --uid 999 postgres; \
    mkdir -p /var/lib/postgresql /var/run/postgresql "$PGDATA" /docker-entrypoint-initdb.d; \
    chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql "$PGDATA"; \
    chmod 2775 /var/run/postgresql; \
    \
    # --- ИСПРАВЛЕНИЕ ЛОКАЛИ ДЛЯ SLIM ОБРАЗА ---
    find /etc/dpkg/dpkg.cfg.d -type f -exec sed -i '/path-exclude.*\/usr\/share\/locale/d' {} +; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends locales tzdata gosu ca-certificates; \
    echo "ru_RU.UTF-8 UTF-8" > /etc/locale.gen; \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen; \
    update-locale LANG=ru_RU.UTF-8; \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=distr,target=/buildsrc \
    set -eux; \
    if [ ! -d "/buildsrc/$PG_MAJOR/core" ] || [ ! -d "/buildsrc/$PG_MAJOR/libs" ]; then \
        echo "ERROR! Folders for version $PG_MAJOR NOT FOUND!" >&2; exit 102; \
    fi; \
    apt-get update; \
    if ls /buildsrc/$PG_MAJOR/libs/*.deb >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends --allow-downgrades /buildsrc/$PG_MAJOR/libs/*.deb; \
    fi; \
    for pkg in libpq5 postgresql-client-$PG_MAJOR postgresql-$PG_MAJOR; do \
        if ! ls /buildsrc/$PG_MAJOR/core/${pkg}_*.deb >/dev/null 2>&1; then \
            echo "ERROR! Missing package $pkg in /buildsrc/$PG_MAJOR/core" >&2; exit 202; \
        fi; \
    done; \
    apt-get install -y --no-install-recommends \
        /buildsrc/$PG_MAJOR/core/libpq5_*.deb \
        /buildsrc/$PG_MAJOR/core/postgresql-client-${PG_MAJOR}_*.deb \
        /buildsrc/$PG_MAJOR/core/postgresql-${PG_MAJOR}_*.deb; \
    if ls /buildsrc/$PG_MAJOR/addons/*.deb >/dev/null 2>&1; then \
        echo "Installing optional addons..."; \
        apt-get install -y --no-install-recommends /buildsrc/$PG_MAJOR/addons/*.deb; \
    fi; \
    rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh docker-healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-healthcheck.sh

VOLUME ["/var/lib/postgresql/data"]
EXPOSE 5432

STOPSIGNAL SIGINT
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD ["docker-healthcheck.sh"]

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
