#!/usr/bin/env bash
# Creates the PRODUCTION database and its own MySQL user (granted on that database only).
# Safe for the shared MySQL server: touches no other schema, user, or global setting.
# Idempotent. Reads DB_USER / DB_PASSWORD / DB_NAME from the production backend/.env.
#
# Usage:  bash infra/prod/create_prod_db.sh [path/to/prod/backend/.env]
#         (default: ~/stock-advisor/stock-advisor-prod/backend/.env; runs `sudo mysql`)
set -euo pipefail

ENV_FILE="${1:-$HOME/stock-advisor/stock-advisor-prod/backend/.env}"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE"; exit 1; }
get_env() { grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2-; }
DB_USER="$(get_env DB_USER)"
DB_PASSWORD="$(get_env DB_PASSWORD)"
DB_NAME="$(get_env DB_NAME)"

[[ "$DB_NAME" == "stock_advisor_prod" ]] || { echo "Refusing: DB_NAME must be stock_advisor_prod"; exit 1; }
[[ "$DB_USER" == "stock_advisor_prod" ]] || { echo "Refusing: DB_USER must be stock_advisor_prod (not the dev user)"; exit 1; }
if [[ ${#DB_PASSWORD} -lt 16 || ! "$DB_PASSWORD" =~ [A-Z] || ! "$DB_PASSWORD" =~ [a-z] \
      || ! "$DB_PASSWORD" =~ [0-9] || ! "$DB_PASSWORD" =~ [-_.+=^*~] \
      || "$DB_PASSWORD" =~ [\'\"\`\$%@:/#\\] ]]; then
  echo "DB_PASSWORD must be 16+ chars with upper, lower, digit and one of - _ . + = ^ * ~"
  exit 1
fi

MYSQL_ADMIN_CMD="${MYSQL_ADMIN_CMD:-sudo mysql}"
$MYSQL_ADMIN_CMD <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD' WITH MAX_USER_CONNECTIONS 20;
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD' WITH MAX_USER_CONNECTIONS 20;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost', '$DB_USER'@'127.0.0.1';
SQL
echo "OK: database $DB_NAME and user $DB_USER ready (max 20 connections)."
