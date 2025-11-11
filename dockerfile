# syntax=docker/dockerfile:1.7
FROM debian:bookworm

# Locale and PostgreSQL default environment variables
ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8 \
    PGDATA=/var/lib/postgresql/data

# Argument for PostgreSQL major version, required at build time
ARG PG_MAJOR
ENV PG_MAJOR=${PG_MAJOR}

# Install essential system libraries and locales, similar to the official postgres image
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        locales \
        tzdata \
        gosu \
        xz-utils \
        zstd \
        libicu72 \
        wget \
        openssl \
        krb5-user \
        libreadline8 \
        libldap-2.5-0 \
        libcurl4 \
        libxml2 \
        libedit2; \
    echo "ru_RU.UTF-8 UTF-8" > /etc/locale.gen; \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen; \
    update-locale LANG=ru_RU.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# Copy distributive tree for all versions: distr/<version>/core, distr/<version>/libs
COPY distr/ /buildsrc/

# Check argument and presence of required folders, show clear errors
RUN set -eux; \
    sep="=============================================================================="; \
    echo "$sep"; \
    if [ -z "$PG_MAJOR" ]; then \
        echo "ERROR! You MUST pass --build-arg PG_MAJOR=<number> (e.g. --build-arg PG_MAJOR=16)" >&2; \
        echo "$sep" >&2; \
        exit 101; \
    fi; \
    if [ ! -d "/buildsrc/$PG_MAJOR/core" ] || [ ! -d "/buildsrc/$PG_MAJOR/libs" ]; then \
        echo "ERROR! Folder /buildsrc/$PG_MAJOR/core and/or /buildsrc/$PG_MAJOR/libs NOT FOUND!" >&2; \
        echo "Existing version folders:" >&2; ls -l /buildsrc/ >&2 || true; \
        echo "Existing core/libs in version:" >&2; ls -l /buildsrc/$PG_MAJOR >&2 || true; \
        echo "$sep" >&2; \
        exit 102; \
    fi; \
    cp -r /buildsrc/$PG_MAJOR/core/ /tmp/pg1c/; \
    cp -r /buildsrc/$PG_MAJOR/libs/ /tmp/pgdeps/

# Install all dependency .deb files, fail if none found
RUN set -eux; \
    apt-get update; \
    if [ -z "$(ls /tmp/pgdeps/*.deb 2>/dev/null)" ]; then \
        echo "ERROR! No dependency .deb files in /tmp/pgdeps for version $PG_MAJOR" >&2; \
        exit 201; \
    fi; \
    apt-get install -y --no-install-recommends --allow-downgrades $(ls /tmp/pgdeps/*.deb | tr '\n' ' '); \
    rm -rf /var/lib/apt/lists/*

# Install main PostgreSQL 1C .deb packages (libpq5, client, server) in strict order, fail if any are missing
RUN set -eux; \
    for pkg in libpq5 postgresql-client-$PG_MAJOR postgresql-$PG_MAJOR; do \
        file=$(ls /tmp/pg1c/${pkg}_*.deb 2>/dev/null || true); \
        if [ -z "$file" ]; then \
            echo "ERROR! Missing package $pkg in /tmp/pg1c, expected deb named: ${pkg}_*.deb" >&2; \
            ls -l /tmp/pg1c >&2 || true; \
            exit 202; \
        fi; \
        dpkg -i $file; \
    done; \
    apt-get -f install -y; \
    rm -rf /var/lib/apt/lists/* /tmp/pg1c /tmp/pgdeps /buildsrc

# Prepare system directories and postgres user/group (with duplication protection)
RUN set -eux; \
    getent group postgres || groupadd -r postgres --gid 999; \
    id -u postgres || useradd -r -g postgres --uid 999 postgres; \
    mkdir -p /var/lib/postgresql /var/run/postgresql "$PGDATA"; \
    chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql "$PGDATA"; \
    chmod 2775 /var/run/postgresql

# Setup PATH for correct Postgres version
ENV PATH="/usr/lib/postgresql/${PG_MAJOR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Create init scripts folder (docker-entrypoint-initdb.d) as in official images
RUN mkdir -p /docker-entrypoint-initdb.d

# Copy entrypoint and healthcheck scripts and set permissions
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-healthcheck.sh

# Postgres/1C defaults for container
ENV POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=ru_RU.UTF-8"
ENV POSTGRES_PASSWORD=""
ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=postgres

VOLUME ["/var/lib/postgresql/data"]

EXPOSE 5432

# Official style docker signal handling for fast/graceful shutdown (as in postgres Dockerfile)
STOPSIGNAL SIGINT

HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD ["docker-healthcheck.sh"]

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
