#!/usr/bin/env bash
# ==============================================================================
# NPO ODOO DOCKER - AUTOMATED PRODUCTION BACKUP SCRIPT
# Inisiatif Turnkey ERP Lembaga Nirlaba Indonesia (Wakaf, Zakat & Lembaga Sosial)
# Standar: BWI (PSAK 412), BAZNAS (PSAK 109), Kemensos (ISAK 35)
# ==============================================================================
# Skrip ini mencadangkan Database PostgreSQL dan Odoo Filestore (dokumen legal,
# kuitansi donasi, akta ikrar wakaf, foto asesmen mustahik) ke satu arsip .tar.gz.
#
# Cocok dijalankan otomatis via cron job harian pada pukul 02:00 malam:
# 0 2 * * * cd /path/to/npo-odoo-docker && ./scripts/backup.sh >> /var/log/npo_backup.log 2>&1
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Muat variabel lingkungan dari .env
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] File .env tidak ditemukan di $PROJECT_ROOT"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TEMP_DIR="$BACKUP_DIR/tmp_${TIMESTAMP}"
BACKUP_FILE="$BACKUP_DIR/npo_backup_${TIMESTAMP}.tar.gz"

echo "===================================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Memulai proses pencadangan Odoo NPO ERP..."
echo "===================================================================="

# Pastikan direktori backup tersedia
mkdir -p "$TEMP_DIR"

# 1. Pengecekan container yang sedang berjalan
if ! docker compose ps --services --filter "status=running" | grep -q "^db$"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Service database (db) tidak berjalan!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if ! docker compose ps --services --filter "status=running" | grep -q "^web$"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Service web Odoo (web) tidak berjalan!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 2. Dump Database PostgreSQL
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [1/4] Mengekspor Database PostgreSQL (${POSTGRES_DB:-postgres})..."
docker compose exec -T db pg_dump -U "${POSTGRES_USER:-odoo}" "${POSTGRES_DB:-postgres}" | gzip > "$TEMP_DIR/database.sql.gz"

if [[ ! -s "$TEMP_DIR/database.sql.gz" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Database dump kosong atau gagal diekspor!"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')]       ✓ Database berhasil diekspor ($(du -h "$TEMP_DIR/database.sql.gz" | cut -f1))"

# 3. Kompresi Odoo Filestore
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [2/4] Mengarsipkan Odoo Filestore (/var/lib/odoo/filestore)..."
docker compose exec -T web tar -czf - -C /var/lib/odoo filestore > "$TEMP_DIR/filestore.tar.gz" 2>/dev/null || true

if [[ ! -f "$TEMP_DIR/filestore.tar.gz" || ! -s "$TEMP_DIR/filestore.tar.gz" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Filestore kosong atau belum terbuat. Menyiapkan arsip filestore kosong..."
    tar -czf "$TEMP_DIR/filestore.tar.gz" -T /dev/null
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')]       ✓ Filestore berhasil diarsipkan ($(du -h "$TEMP_DIR/filestore.tar.gz" | cut -f1))"

# 4. Buat file manifest informasi backup
cat <<EOF > "$TEMP_DIR/manifest.json"
{
  "system": "npo-odoo-docker",
  "profile": "${NPO_PROFILE:-1}",
  "timestamp": "${TIMESTAMP}",
  "database": "${POSTGRES_DB:-postgres}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# 5. Gabungkan ke dalam satu arsip terenkapsulasi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [3/4] Menggabungkan arsip backup final..."
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" database.sql.gz filestore.tar.gz manifest.json
rm -rf "$TEMP_DIR"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date '+%Y-%m-%d %H:%M:%S')]       ✓ File backup selesai dibuat: $BACKUP_FILE ($BACKUP_SIZE)"

# 6. Rotasi Pencadangan Lokal (> RETENTION_DAYS hari)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [4/4] Memeriksa rotasi backup lokal (> $RETENTION_DAYS hari)..."
find "$BACKUP_DIR" -name "npo_backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -exec rm -f {} \; 2>/dev/null || true
find "$BACKUP_DIR" -name "waqf_backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -exec rm -f {} \; 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')]       ✓ Pembersihan arsip usang lokal selesai."

# 7. Upload Offsite via Rclone (Jika dikonfigurasi)
if [[ -n "${RCLONE_REMOTE:-}" ]]; then
    DEST_PATH="${RCLONE_DEST_PATH:-NpoOdooBackups}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OFFSITE] Mengunggah backup ke cloud storage (${RCLONE_REMOTE}:${DEST_PATH})..."
    if command -v rclone &> /dev/null; then
        rclone copy "$BACKUP_FILE" "${RCLONE_REMOTE}:${DEST_PATH}" --stats-one-line -v
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]       ✓ Upload offsite selesai."
        
        # Rotasi offsite jika didukung rclone
        rclone delete --min-age "${RETENTION_DAYS}d" "${RCLONE_REMOTE}:${DEST_PATH}" 2>/dev/null || true
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] Utilitas rclone belum terpasang di host VPS. Lewati upload offsite."
    fi
fi

echo "===================================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] PENCADANGAN BERHASIL DISELESAIKAN!"
echo "===================================================================="
