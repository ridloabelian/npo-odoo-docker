#!/usr/bin/env bash
# ==============================================================================
# NPO ODOO DOCKER - PRODUCTION SECURITY HARDENING SCRIPT
# Inisiatif Turnkey ERP Lembaga Nirlaba Indonesia (Wakaf, Zakat & Lembaga Sosial)
# ==============================================================================
# Skrip ini mengunci antarmuka database Odoo ke mode produksi penuh (list_db = False)
# untuk mencegah pihak publik melihat daftar database, membuat, atau memanipulasi DB.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "===================================================================="
echo "    MENGUNCI SISTEM ODOO KE MODE PRODUKSI (list_db = False)         "
echo "===================================================================="

# 1. Pastikan di .env diset LIST_DB=False
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    if grep -q "^LIST_DB=" "$PROJECT_ROOT/.env"; then
        sed -i 's/^LIST_DB=.*/LIST_DB=False/g' "$PROJECT_ROOT/.env"
    else
        echo "LIST_DB=False" >> "$PROJECT_ROOT/.env"
    fi
fi

# 2. Update config/odoo.conf
if [[ -f "$PROJECT_ROOT/config/odoo.conf" ]]; then
    sed -i 's/^list_db = .*/list_db = False/g' "$PROJECT_ROOT/config/odoo.conf"
    echo "✓ config/odoo.conf berhasil diperbarui: list_db = False"
fi

# 3. Restart container web Odoo
echo "Merestart container web Odoo agar konfigurasi keamanan baru diterapkan..."
docker compose restart web

echo "===================================================================="
echo "SISTEM BERHASIL DIKUNCI KE MODE PRODUKSI!"
echo "Pemilih database (/web/database/selector) kini tersembunyi dari publik."
echo "===================================================================="
