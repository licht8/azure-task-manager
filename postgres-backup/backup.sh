#!/bin/bash

set -e

echo "============================================================"
echo "Azure PostgreSQL Backup"
echo "============================================================"

if [ -z "$DATABASE_URL" ]; then
    echo "[FAILED] DATABASE_URL is not configured."
    exit 1
fi

if [ -z "$STORAGE_ACCOUNT" ]; then
    echo "[FAILED] STORAGE_ACCOUNT is not configured."
    exit 1
fi

if [ -z "$BACKUP_CONTAINER" ]; then
    echo "[FAILED] BACKUP_CONTAINER is not configured."
    exit 1
fi

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
FILE="tasks_${TIMESTAMP}.dump"
LOCAL_FILE="/tmp/${FILE}"
BLOB_NAME="backups/${FILE}"

echo "[INFO] Creating PostgreSQL dump..."

pg_dump \
    "$DATABASE_URL" \
    --format=custom \
    --file="$LOCAL_FILE"

if [ ! -f "$LOCAL_FILE" ]; then
    echo "[FAILED] Dump file was not created."
    exit 1
fi

SIZE=$(du -h "$LOCAL_FILE" | cut -f1)

echo "[PASS] PostgreSQL dump created"
echo "[INFO] Size: $SIZE"

echo "[INFO] Authenticating with Managed Identity..."

az login \
    --identity \
    --client-id "$AZURE_CLIENT_ID" \
    --allow-no-subscriptions \
    >/dev/null

echo "[PASS] Managed Identity authenticated"

echo "[INFO] Uploading backup to Azure Blob Storage..."

az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$BACKUP_CONTAINER" \
    --name "$BLOB_NAME" \
    --file "$LOCAL_FILE" \
    --auth-mode login \
    --overwrite true \
    --output none

echo "[PASS] Backup uploaded"

echo "[INFO] Blob: $BLOB_NAME"
echo "[INFO] Size: $SIZE"

rm -f "$LOCAL_FILE"

echo "[PASS] PostgreSQL backup completed successfully"