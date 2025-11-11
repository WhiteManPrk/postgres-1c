#!/usr/bin/env bash
set -e
pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" -h 127.0.0.1 -p 5432
