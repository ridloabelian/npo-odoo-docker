#!/usr/bin/env bash
# ==============================================================================
# NPO ODOO DOCKER - DISASTER RECOVERY & RESTORE SCRIPT
# Inisiatif Turnkey ERP Lembaga Nirlaba Indonesia (Wakaf, Zakat & Lembaga Sosial)
# Standar: BWI (PSAK 412), BAZNAS (PSAK 109), Kemensos (ISAK 35)
# ==============================================================================
# Skrip pemulihan bencana (Disaster Recovery) 1-perintah:
# Penggunaan: ./scripts/restore.sh backups/npo_backup_YYYYMMDD_HHMMSS.tar.gz
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

if [[ $# -lt 1 ]]; then
    echo "===================================================================="
    echo "PANDUAN PEMULIHAN DATA (DISASTER RECOVERY):"
    echo "Penggunaan: $0 <path_ke_file_backup.tar.gz>"
    echo "Contoh:     $0 backups/npo_backup_20260924_120000.tar.gz"
    echo "===================================================================="
    exit 1
fi

BACKUP_ARCHIVE="$1"

if [[ ! -f "$BACKUP_ARCHIVE" ]]; then
    echo "[ERROR] File arsip backup tidak ditemukan: $BACKUP_ARCHIVE"
    exit 1
fi

# Muat konfigurasi dari .env
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "[ERROR] File .env tidak ditemukan di $PROJECT_ROOT"
    exit 1
fi

echo "===================================================================="
echo "          PEMULIHAN DATA (DISASTER RECOVERY) NPO ODOO ERP           "
echo "===================================================================="
echo "PERINGATAN: Tindakan ini akan menimpa seluruh database '${POSTGRES_DB:-postgres}'"
echo "dan filestore yang ada saat ini dengan data dari file cadangan:"
echo "-> $BACKUP_ARCHIVE"
echo "===================================================================="
echo ""
read -r -p "Ketik 'YA' dengan huruf kapital untuk melanjutkan proses restore: " CONFIRM

if [[ "$CONFIRM" != "YA" ]]; then
    echo "Pemulihan data dibatalkan oleh pengguna."
    exit 0
fi

TEMP_EXTRACT="$PROJECT_ROOT/backups/restore_tmp_$(date +%s)"
mkdir -p "$TEMP_EXTRACT"

echo ""
echo "[1/4] Mengekstrak arsip cadangan ke direktori sementara..."
tar -xzf "$BACKUP_ARCHIVE" -C "$TEMP_EXTRACT"

if [[ ! -f "$TEMP_EXTRACT/database.sql.gz" ]]; then
    echo "[ERROR] Arsip backup tidak memiliki file 'database.sql.gz' yang valid!"
    rm -rf "$TEMP_EXTRACT"
    exit 1
fi

# Tampilkan metadata jika ada
if [[ -f "$TEMP_EXTRACT/manifest.json" ]]; then
    echo "      ✓ Metadata arsip terverifikasi."
fi

echo "[2/4] Menghentikan service web Odoo sementara..."
docker compose stop web

echo "[3/4] Memulihkan database PostgreSQL..."
# Drop database lama jika ada dan buat ulang secara bersih
docker compose exec -T db dropdb -U "${POSTGRES_USER:-odoo}" --if-exists "${POSTGRES_DB:-postgres}" 2>/dev/null || true
docker compose exec -T db createdb -U "${POSTGRES_USER:-odoo}" "${POSTGRES_DB:-postgres}"
gunzip -c "$TEMP_EXTRACT/database.sql.gz" | docker compose exec -T db psql -U "${POSTGRES_USER:-odoo}" -d "${POSTGRES_DB:-postgres}" > /dev/null

echo "      ✓ Database PostgreSQL berhasil dipulihkan."

if [[ -f "$TEMP_EXTRACT/filestore.tar.gz" ]]; then
    echo "[4/4] Memulihkan Odoo Filestore..."
    docker compose exec -T web mkdir -p /var/lib/odoo/filestore 2>/dev/null || true
    docker compose cp "$TEMP_EXTRACT/filestore.tar.gz" web:/tmp/filestore.tar.gz
    docker compose exec -T web tar -xzf /tmp/filestore.tar.gz -C /var/lib/odoo/
    docker compose exec -T web rm -f /tmp/filestore.tar.gz
    echo "      ✓ Odoo Filestore berhasil dipulihkan."
fi

rm -rf "$TEMP_EXTRACT"

echo "Menghidupkan kembali service web Odoo..."
docker compose start web

echo ""
echo "===================================================================="
echo "SISTEM DAN DATA BERHASIL DIPULIHKAN DENGAN SEMPURNA!"
echo "Akses Odoo Anda di: https://${DOMAIN_NAME:-localhost}"
echo "===================================================================="
