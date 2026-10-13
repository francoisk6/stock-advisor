#!/usr/bin/env bash
# Creates the Stock Adviser dev + test databases and a dedicated MySQL user restricted to them.
# Safe for the shared MySQL server: touches no other schema, user, or global setting.
# Idempotent. Reads DB_USER / DB_PASSWORD / DB_NAME from backend/.env.
#
# Usage:  bash infra/mysql/create_dev_db.sh
#         MYSQL_ADMIN_CMD="mysql -u root -p" bash infra/mysql/create_dev_db.sh   # if root uses a password
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/backend/.env"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE (copy backend/.env.example)"; exit 1; }

get_env() { grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2-; }
DB_USER="$(get_env DB_USER)"
DB_PASSWORD="$(get_env DB_PASSWORD)"
DB_NAME="$(get_env DB_NAME)"
TEST_DB_NAME="${DB_NAME%_dev}_test"

[[ "$DB_NAME" == stock_advisor_* ]] || { echo "Refusing: DB_NAME must start with stock_advisor_"; exit 1; }
[[ "$DB_PASSWORD" != "change-me" && -n "$DB_PASSWORD" ]] || { echo "Set DB_PASSWORD in $ENV_FILE"; exit 1; }
# Server enforces validate_password (mixed case + digit + special). Quotes, $, %, @, :, /, # and
# backslash are rejected here because they break SQL quoting, URLs or .env parsing.
if [[ ${#DB_PASSWORD} -lt 12 || ! "$DB_PASSWORD" =~ [A-Z] || ! "$DB_PASSWORD" =~ [a-z] \
      || ! "$DB_PASSWORD" =~ [0-9] || ! "$DB_PASSWORD" =~ [-_.+=^*~] \
      || "$DB_PASSWORD" =~ [\'\"\`\$%@:/#\\] ]]; then
  echo "DB_PASSWORD must be 12+ chars with upper, lower, digit and one of - _ . + = ^ * ~"
  exit 1
fi

MYSQL_ADMIN_CMD="${MYSQL_ADMIN_CMD:-sudo mysql}"

$MYSQL_ADMIN_CMD <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS \`$TEST_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' WITH MAX_USER_CONNECTIONS 30;
ALTER USER '$DB_USER'@'127.0.0.1' WITH MAX_USER_CONNECTIONS 30;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost', '$DB_USER'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$TEST_DB_NAME\`.* TO '$DB_USER'@'localhost', '$DB_USER'@'127.0.0.1';
SQL

echo "OK: databases $DB_NAME, $TEST_DB_NAME and user $DB_USER ready (max 30 connections)."
