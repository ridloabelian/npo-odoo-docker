#!/usr/bin/env bash
# ==============================================================================
# NPO ODOO DOCKER - MODULE DOWNLOAD & UPDATE UTILITY
# Inisiatif Turnkey ERP Lembaga Nirlaba Indonesia (Wakaf, Zakat & Lembaga Sosial)
# Standar: BWI (PSAK 412), BAZNAS (PSAK 109), Kemensos (ISAK 35)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRA_ADDONS_DIR="$PROJECT_ROOT/extra-addons"

cd "$PROJECT_ROOT"

# Muat variabel lingkungan dari .env jika ada
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

BRANCH="${MODULES_BRANCH:-19.0}"
PROFILE="${NPO_PROFILE:-1}"

echo "===================================================================="
echo "      UNDUH / PERBARUI EKOSISTEM MODUL NIRLABA INDONESIA           "
echo "===================================================================="
echo "Direktori Target: $EXTRA_ADDONS_DIR"
echo "Profil Aktif    : Profil $PROFILE"
echo "Branch Git      : $BRANCH"
echo "===================================================================="

mkdir -p "$EXTRA_ADDONS_DIR"

sync_one_repo() {
    local REPO_NAME="$1"
    local REPO_URL_DEFAULT="https://github.com/ridloabelian/${REPO_NAME}.git"
    local TARGET_DIR="$EXTRA_ADDONS_DIR/${REPO_NAME}"
    local LOCAL_SOURCE="$PROJECT_ROOT/${REPO_NAME}"

    echo ""
    echo "→ Memproses repositori: ${REPO_NAME}"

    if [[ -d "$LOCAL_SOURCE" ]]; then
        echo "  Menggunakan sumber lokal dari $LOCAL_SOURCE..."
        rm -rf "$TARGET_DIR"
        cp -r "$LOCAL_SOURCE" "$TARGET_DIR"
    elif [[ -d "$TARGET_DIR/.git" ]]; then
        echo "  Memperbarui modul via git pull..."
        git -C "$TARGET_DIR" checkout "$BRANCH" 2>/dev/null || true
        git -C "$TARGET_DIR" pull --ff-only 2>/dev/null || true
    else
        echo "  Mengkloning dari ${REPO_URL_DEFAULT}..."
        git clone --branch "$BRANCH" --depth 1 "$REPO_URL_DEFAULT" "$TARGET_DIR" 2>/dev/null || {
            echo "  [WARN] Kloning remote tidak dapat diselesaikan. Menyiapkan direktori lokal..."
            mkdir -p "$TARGET_DIR"
        }
    fi

    # Link module individual ke ./extra-addons
    if [[ -d "$TARGET_DIR" ]]; then
        for item in "$TARGET_DIR"/*; do
            if [[ -d "$item" && -f "$item/__manifest__.py" ]]; then
                local module_name
                module_name=$(basename "$item")
                ln -sfn "../${REPO_NAME}/${module_name}" "$EXTRA_ADDONS_DIR/${module_name}" 2>/dev/null || true
            fi
        done
    fi
}

case "$PROFILE" in
    1)
        sync_one_repo "npo-core-modules"
        sync_one_repo "waqf-odoo-modules"
        ;;
    2)
        sync_one_repo "npo-core-modules"
        sync_one_repo "zakat-odoo-modules"
        ;;
    3)
        sync_one_repo "npo-core-modules"
        sync_one_repo "lks-odoo-modules"
        ;;
    4)
        sync_one_repo "npo-core-modules"
        sync_one_repo "waqf-odoo-modules"
        sync_one_repo "zakat-odoo-modules"
        sync_one_repo "lks-odoo-modules"
        ;;
esac

# Set permission
chmod -R 755 "$EXTRA_ADDONS_DIR"

echo ""
echo "===================================================================="
echo "Daftar Modul yang Tersedia di $EXTRA_ADDONS_DIR:"
ls -la "$EXTRA_ADDONS_DIR"
echo "===================================================================="
echo "Untuk mengaktifkan modul di antarmuka Odoo:"
echo "1. Buka Odoo dengan hak Administrator."
echo "2. Aktifkan Developer Mode (Pengaturan -> Aktifkan mode pengembang)."
echo "3. Buka menu Apps -> Klik 'Update Apps List'."
echo "4. Cari modul sesuai sektor (Wakaf / Zakat / LKS / NPO) lalu klik Install."
echo "===================================================================="
