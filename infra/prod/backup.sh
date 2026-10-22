#!/usr/bin/env bash
# Nightly dump of the production database (own MySQL user, own DB only), keeping the newest 14.
# Low priority for the shared server. Run from cron (see infra/prod/crontab.txt).
set -euo pipefail

PROD="$HOME/stock-advisor/stock-advisor-prod"
ENV_FILE="$PROD/backend/.env"
DEST="${BACKUP_DIR:-$HOME/backups/stock-advisor}"
KEEP=14
get_env() { grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2-; }

mkdir -p "$DEST"
chmod 700 "$DEST"
# Password via a private option file, never on the command line (visible in `ps`).
CNF="$(mktemp)"
trap 'rm -f "$CNF"' EXIT
chmod 600 "$CNF"
printf '[client]\nuser=%s\npassword=%s\nhost=127.0.0.1\n' \
  "$(get_env DB_USER)" "$(get_env DB_PASSWORD)" > "$CNF"

FILE="$DEST/prod-$(date -u +%Y%m%d-%H%M).sql.gz"
if nice -n 19 mysqldump --defaults-extra-file="$CNF" --single-transaction --quick \
     --no-tablespaces --routines "$(get_env DB_NAME)" | gzip -6 > "$FILE.part"; then
  mv "$FILE.part" "$FILE"
  chmod 600 "$FILE"
  ls -1t "$DEST"/prod-*.sql.gz | tail -n +$((KEEP + 1)) | xargs -r rm -f
  echo "Backup written: $FILE ($(du -h "$FILE" | cut -f1))"
else
  rm -f "$FILE.part"
  (cd "$PROD/backend" && .venv/bin/python -m app.ops alert "Backup FAILED" \
    "The nightly database backup failed on $(hostname) at $(date -u '+%F %T') UTC.")
  exit 1
fi
