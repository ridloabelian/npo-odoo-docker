#!/usr/bin/env bash
# ==============================================================================
# NPO ODOO DOCKER - INITIAL SETUP & PROVISIONING WIZARD
# Inisiatif Turnkey ERP Lembaga Nirlaba Indonesia (Wakaf, Zakat & Lembaga Sosial)
# Standar: BWI (PSAK 412), BAZNAS (PSAK 109), Kemensos (ISAK 35)
# ==============================================================================
set -euo pipefail

# Pewarnaan Output Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}======================================================================${NC}"
echo -e "${BOLD}${CYAN}      NPO ODOO DOCKER - TURNKEY INSTALLATION & PROVISIONING          ${NC}"
echo -e "${PURPLE}  Sistem ERP Terpadu Nirlaba Indonesia (Wakaf, Zakat & Sosial/LKS)   ${NC}"
echo -e "${YELLOW}  Standar: BWI (PSAK 412) × BAZNAS (PSAK 109) × Kemensos (ISAK 35)   ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# 1. Pengecekan Hak Akses Root / Sudo
# ------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}[PERINGATAN] Anda tidak menjalankan skrip ini sebagai root.${NC}"
    echo -e "${YELLOW}Konfigurasi Swap File 2 GB memerlukan akses root/sudo jika RAM < 8 GB.${NC}"
    echo ""
fi

# ------------------------------------------------------------------------------
# 2. Pengecekan Docker & Docker Compose v2
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/6] Memeriksa Kesiapan Docker & Docker Compose v2...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR] Docker belum terpasang di VPS ini!${NC}"
    echo -e "${YELLOW}Silakan pasang Docker Engine resmi terlebih dahulu:${NC}"
    echo -e "  curl -fsSL https://get.docker.com | sh"
    echo -e "  sudo usermod -aG docker \$USER"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}[ERROR] Docker Compose (v2) belum terpasang atau plugin compose tidak ditemukan!${NC}"
    echo -e "${YELLOW}Silakan pasang plugin docker-compose-plugin:${NC}"
    echo -e "  sudo apt-get update && sudo apt-get install -y docker-compose-plugin"
    exit 1
fi

echo -e "  ${GREEN}✓ Docker terdeteksi:${NC} $(docker --version)"
echo -e "  ${GREEN}✓ Docker Compose terdeteksi:${NC} $(docker compose version)"

# ------------------------------------------------------------------------------
# 3. Pengecekan & Pembuatan Swap File 2 GB (Jika RAM Server < 8 GB)
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[2/6] Memeriksa Kapasitas RAM & Alokasi Swap Memory Server...${NC}"

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
SWAP_SIZE_MB=$(free -m | awk '/^Swap:/ {print $2}')

echo -e "  - Total RAM Terdeteksi: ${CYAN}${TOTAL_RAM_MB} MB${NC}"
echo -e "  - Total Swap Terdeteksi: ${CYAN}${SWAP_SIZE_MB} MB${NC}"

if [[ "$TOTAL_RAM_MB" -lt 8192 ]]; then
    echo -e "  ${YELLOW}! RAM server < 8 GB (${TOTAL_RAM_MB} MB). Memeriksa alokasi Swap...${NC}"
    if [[ "$SWAP_SIZE_MB" -lt 2048 ]]; then
        echo -e "  ${YELLOW}! Swap saat ini ${SWAP_SIZE_MB} MB (< 2048 MB). Menyiapkan Swap 2 GB...${NC}"
        if [[ $EUID -eq 0 ]]; then
            echo -e "  ${BLUE}→ Membuat Swap File 2 GB di /swapfile demi stabilitas proses Odoo...${NC}"
            if [[ ! -f /swapfile ]]; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                if ! grep -q '/swapfile' /etc/fstab; then
                    echo '/swapfile none swap sw 0 0' >> /etc/fstab
                fi
                sysctl vm.swappiness=10
                if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
                    echo 'vm.swappiness=10' >> /etc/sysctl.conf
                fi
                echo -e "  ${GREEN}✓ Swap File 2 GB berhasil dibuat, diaktifkan, dan didaftarkan ke /etc/fstab.${NC}"
            else
                echo -e "  ${YELLOW}! /swapfile sudah ada namun belum aktif penuh. Menjalankan swapon...${NC}"
                swapon /swapfile 2>/dev/null || true
                echo -e "  ${GREEN}✓ /swapfile diaktifkan.${NC}"
            fi
        else
            echo -e "  ${RED}! Gagal membuat swap otomatis karena membutuhkan akses root/sudo.${NC}"
            echo -e "  ${YELLOW}  Jalankan perintah berikut secara manual dengan sudo:${NC}"
            echo -e "  sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        fi
    else
        echo -e "  ${GREEN}✓ Alokasi Swap mencukupi:${NC} ${SWAP_SIZE_MB} MB (>= 2048 MB)"
    fi
else
    echo -e "  ${GREEN}✓ RAM server memadai (>= 8 GB). Alokasi swap bersifat opsional.${NC}"
fi

# ------------------------------------------------------------------------------
# 4. Menu Interaktif Pemilihan Profil Sistem Nirlaba
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[3/6] Pemilihan Profil Ekosistem Nirlaba...${NC}"

SELECTED_PROFILE="${NPO_PROFILE:-}"

# Parse command line argument jika ada (--profile N)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            SELECTED_PROFILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$SELECTED_PROFILE" ]]; then
    echo -e "${CYAN}----------------------------------------------------------------------${NC}"
    echo -e "${BOLD}Pilih Profil Sistem Nirlaba Anda:${NC}"
    echo -e "  ${GREEN}[1] Sektor Wakaf (Badan Wakaf Indonesia - PSAK 412)${NC}"
    echo -e "      -> Mengunduh: npo-core-modules + waqf-odoo-modules"
    echo -e "  ${GREEN}[2] Sektor Zakat & Donasi (BAZNAS - PSAK 109)${NC}"
    echo -e "      -> Mengunduh: npo-core-modules + zakat-odoo-modules"
    echo -e "  ${GREEN}[3] Sektor Lembaga Kesejahteraan Sosial / Panti (Kemensos - ISAK 35)${NC}"
    echo -e "      -> Mengunduh: npo-core-modules + lks-odoo-modules"
    echo -e "  ${GREEN}[4] Yayasan Terpadu / All-in-One (Wakaf + Zakat + LKS)${NC}"
    echo -e "      -> Mengunduh seluruh ekosistem modul ke ./extra-addons"
    echo -e "${CYAN}----------------------------------------------------------------------${NC}"
    
    while true; do
        read -r -p "Masukkan pilihan profil [1/2/3/4] (default: 1): " USER_CHOICE
        USER_CHOICE="${USER_CHOICE:-1}"
        case "$USER_CHOICE" in
            1|2|3|4)
                SELECTED_PROFILE="$USER_CHOICE"
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid! Masukkan angka 1, 2, 3, atau 4.${NC}"
                ;;
        esac
    done
fi

case "$SELECTED_PROFILE" in
    1)
        PROFILE_LABEL="Sektor Wakaf (BWI - PSAK 412)"
        REQUIRED_REPOS=("npo-core-modules" "waqf-odoo-modules")
        ADDONS_PATH="/mnt/extra-addons/npo-core-modules,/mnt/extra-addons/waqf-odoo-modules,/mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons"
        ;;
    2)
        PROFILE_LABEL="Sektor Zakat & Donasi (BAZNAS - PSAK 109)"
        REQUIRED_REPOS=("npo-core-modules" "zakat-odoo-modules")
        ADDONS_PATH="/mnt/extra-addons/npo-core-modules,/mnt/extra-addons/zakat-odoo-modules,/mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons"
        ;;
    3)
        PROFILE_LABEL="Sektor Lembaga Kesejahteraan Sosial / Panti (Kemensos - ISAK 35)"
        REQUIRED_REPOS=("npo-core-modules" "lks-odoo-modules")
        ADDONS_PATH="/mnt/extra-addons/npo-core-modules,/mnt/extra-addons/lks-odoo-modules,/mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons"
        ;;
    4)
        PROFILE_LABEL="Yayasan Terpadu / All-in-One (Wakaf + Zakat + LKS)"
        REQUIRED_REPOS=("npo-core-modules" "waqf-odoo-modules" "zakat-odoo-modules" "lks-odoo-modules")
        ADDONS_PATH="/mnt/extra-addons/npo-core-modules,/mnt/extra-addons/waqf-odoo-modules,/mnt/extra-addons/zakat-odoo-modules,/mnt/extra-addons/lks-odoo-modules,/mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons"
        ;;
    *)
        echo -e "${RED}[ERROR] Profil tidak dikenali: $SELECTED_PROFILE${NC}"
        exit 1
        ;;
esac

echo -e "  ${GREEN}✓ Profil Aktif:${NC} ${BOLD}${PROFILE_LABEL}${NC}"

# ------------------------------------------------------------------------------
# 5. Konfigurasi .env & Pembuatan Password Acak Kuat
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[4/6] Menyiapkan Variabel Lingkungan (.env)...${NC}"

generate_strong_password() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24
    else
        head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 24
    fi
}

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo -e "  ${GREEN}✓ File .env berhasil dibuat dari template .env.example${NC}"
    else
        echo -e "${RED}[ERROR] File .env.example tidak ditemukan!${NC}"
        exit 1
    fi
fi

# Generate Password Acak Kuat
RAND_DB_PASS=$(generate_strong_password)
RAND_ADMIN_PASS=$(generate_strong_password)

if grep -q "GantiDenganPasswordDatabaseYangSangatKuatDanAman123!" "$ENV_FILE"; then
    sed -i "s|POSTGRES_PASSWORD=GantiDenganPasswordDatabaseYangSangatKuatDanAman123!|POSTGRES_PASSWORD=${RAND_DB_PASS}|g" "$ENV_FILE"
    echo -e "  ${GREEN}✓ Generated Password Database PostgreSQL yang kuat secara otomatis.${NC}"
fi

if grep -q "GantiDenganMasterPasswordOdooYangSangatKuatDanAman123!" "$ENV_FILE"; then
    sed -i "s|ADMIN_PASSWORD=GantiDenganMasterPasswordOdooYangSangatKuatDanAman123!|ADMIN_PASSWORD=${RAND_ADMIN_PASS}|g" "$ENV_FILE"
    echo -e "  ${GREEN}✓ Generated Odoo Master Admin Password yang kuat secara otomatis.${NC}"
fi

# Update Profil & Addons Path di .env
if grep -q "^NPO_PROFILE=" "$ENV_FILE"; then
    sed -i "s|^NPO_PROFILE=.*|NPO_PROFILE=${SELECTED_PROFILE}|g" "$ENV_FILE"
else
    echo "NPO_PROFILE=${SELECTED_PROFILE}" >> "$ENV_FILE"
fi

if grep -q "^ODOO_ADDONS_PATH=" "$ENV_FILE"; then
    sed -i "s|^ODOO_ADDONS_PATH=.*|ODOO_ADDONS_PATH=${ADDONS_PATH}|g" "$ENV_FILE"
else
    echo "ODOO_ADDONS_PATH=${ADDONS_PATH}" >> "$ENV_FILE"
fi

# ------------------------------------------------------------------------------
# 6. Unduh / Sinkronkan Ekosistem Modul ke ./extra-addons
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[5/6] Mengunduh & Menyiapkan Modul untuk ${PROFILE_LABEL}...${NC}"

mkdir -p ./extra-addons
mkdir -p ./backups
mkdir -p ./config

# Helper untuk mengunduh atau menyalin modul
sync_repo() {
    local REPO_NAME="$1"
    local REPO_URL_DEFAULT="https://github.com/ridloabelian/${REPO_NAME}.git"
    local TARGET_DIR="./extra-addons/${REPO_NAME}"
    local LOCAL_SOURCE="./${REPO_NAME}"
    local BRANCH="${MODULES_BRANCH:-19.0}"

    echo -e "  ${CYAN}→ Memproses repositori modul:${NC} ${BOLD}${REPO_NAME}${NC}"

    # 1. Jika direktori lokal sudah tersedia di project root
    if [[ -d "$LOCAL_SOURCE" ]]; then
        echo -e "    Menggunakan sumber lokal: ${LOCAL_SOURCE}"
        rm -rf "$TARGET_DIR"
        cp -r "$LOCAL_SOURCE" "$TARGET_DIR"
    # 2. Jika sudah ada git repo di target
    elif [[ -d "$TARGET_DIR/.git" ]]; then
        echo -e "    Memperbarui modul via git pull..."
        git -C "$TARGET_DIR" checkout "$BRANCH" 2>/dev/null || true
        git -C "$TARGET_DIR" pull --ff-only 2>/dev/null || true
    # 3. Kloning dari remote git
    else
        echo -e "    Mengunduh dari remote: ${REPO_URL_DEFAULT} (branch: ${BRANCH})..."
        if git clone --branch "$BRANCH" --depth 1 "$REPO_URL_DEFAULT" "$TARGET_DIR" 2>/dev/null; then
            echo -e "    ${GREEN}✓ Kloning modul ${REPO_NAME} berhasil.${NC}"
        else
            echo -e "    ${YELLOW}! Repositori remote belum dapat diakses langsung. Menyiapkan struktur lokal fallback...${NC}"
            mkdir -p "$TARGET_DIR"
        fi
    fi

    # Buat symlink individual modul ke ./extra-addons agar Odoo mudah mengenali
    if [[ -d "$TARGET_DIR" ]]; then
        for item in "$TARGET_DIR"/*; do
            if [[ -d "$item" && -f "$item/__manifest__.py" ]]; then
                local module_name
                module_name=$(basename "$item")
                ln -sfn "../${REPO_NAME}/${module_name}" "./extra-addons/${module_name}" 2>/dev/null || true
            fi
        done
    fi
}

for repo in "${REQUIRED_REPOS[@]}"; do
    sync_repo "$repo"
done

# Pastikan modul waqf yang sudah ada di root juga terlink jika Profil 1 atau 4
if [[ "$SELECTED_PROFILE" == "1" || "$SELECTED_PROFILE" == "4" ]]; then
    for w_mod in waqf_core waqf_distribution waqf_asset_management l10n_id_waqf_psak112; do
        if [[ -d "./${w_mod}" && -f "./${w_mod}/__manifest__.py" ]]; then
            ln -sfn "../${w_mod}" "./extra-addons/${w_mod}" 2>/dev/null || true
        fi
    done
fi

# Set izin akses direktori
chmod -R 755 ./extra-addons
chmod -R 755 ./config
chmod -R 755 ./scripts
chmod -R 700 ./backups
chmod +x ./scripts/*.sh

echo -e "  ${GREEN}✓ Ekosistem modul berhasil disiapkan di ./extra-addons${NC}"

# ------------------------------------------------------------------------------
# 7. Sinkronisasi config/odoo.conf dari config/odoo.conf.template
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[6/6] Mengonfigurasi config/odoo.conf & Keamanan list_db = False...${NC}"

# Baca nilai aktual dari .env
CURRENT_ADMIN_PASS=$(grep -E '^ADMIN_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2-)
CURRENT_WORKERS=$(grep -E '^ODOO_WORKERS=' "$ENV_FILE" | cut -d '=' -f2- || echo "4")
CURRENT_LIMIT_SOFT=$(grep -E '^ODOO_LIMIT_MEMORY_SOFT=' "$ENV_FILE" | cut -d '=' -f2- || echo "2147483648")
CURRENT_LIMIT_HARD=$(grep -E '^ODOO_LIMIT_MEMORY_HARD=' "$ENV_FILE" | cut -d '=' -f2- || echo "2684354560")
CURRENT_TIME_CPU=$(grep -E '^ODOO_LIMIT_TIME_CPU=' "$ENV_FILE" | cut -d '=' -f2- || echo "600")
CURRENT_TIME_REAL=$(grep -E '^ODOO_LIMIT_TIME_REAL=' "$ENV_FILE" | cut -d '=' -f2- || echo "1200")
CURRENT_LIST_DB=$(grep -E '^LIST_DB=' "$ENV_FILE" | cut -d '=' -f2- || echo "False")

if [[ -f "config/odoo.conf.template" ]]; then
    sed -e "s|\${ADMIN_PASSWORD}|${CURRENT_ADMIN_PASS}|g" \
        -e "s|\${ODOO_WORKERS}|${CURRENT_WORKERS}|g" \
        -e "s|\${ODOO_LIMIT_MEMORY_SOFT}|${CURRENT_LIMIT_SOFT}|g" \
        -e "s|\${ODOO_LIMIT_MEMORY_HARD}|${CURRENT_LIMIT_HARD}|g" \
        -e "s|\${ODOO_LIMIT_TIME_CPU}|${CURRENT_TIME_CPU}|g" \
        -e "s|\${ODOO_LIMIT_TIME_REAL}|${CURRENT_TIME_REAL}|g" \
        -e "s|\${LIST_DB}|${CURRENT_LIST_DB}|g" \
        -e "s|\${ODOO_ADDONS_PATH}|${ADDONS_PATH}|g" \
        config/odoo.conf.template > config/odoo.conf
    echo -e "  ${GREEN}✓ config/odoo.conf berhasil digenerate dengan addons_path & parameter produksi.${NC}"
fi

# ------------------------------------------------------------------------------
# RANGKUMAN & PETUNJUK DEPLOY PRODUKSI
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}        INISIALISASI SELESAI & SISTEM SIAP DI-DEPLOY!                 ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""
echo -e "${BOLD}Informasi Konfigurasi Sistem:${NC}"
echo -e "  - Profil Terpilih   : ${CYAN}${PROFILE_LABEL}${NC}"
echo -e "  - Addons Path       : ${PURPLE}${ADDONS_PATH}${NC}"
echo -e "  - Database Password : ${YELLOW}(Tersimpan aman di file .env)${NC}"
echo -e "  - Master Password   : ${YELLOW}${CURRENT_ADMIN_PASS}${NC}"
echo -e "  - Proteksi list_db  : ${GREEN}${CURRENT_LIST_DB}${NC} (Database selector terproteksi)"
echo ""
echo -e "${BOLD}${YELLOW}LANGKAH BERIKUTNYA UNTUK MENJALANKAN:${NC}"
echo -e "1. Sesuaikan nama domain dan email SSL di ${CYAN}.env${NC}:"
echo -e "   ${BLUE}nano .env${NC}"
echo -e "   (Set ${CYAN}DOMAIN_NAME=erp.yayasananda.or.id${NC} dan ${CYAN}ACME_EMAIL=admin@yayasananda.or.id${NC})"
echo ""
echo -e "2. Jalankan sistem Odoo dengan 1 perintah Docker Compose:"
echo -e "   ${GREEN}docker compose up -d${NC}"
echo ""
echo -e "3. Inisiasi Database Pertama Kali:"
echo -e "   - Buka browser: ${PURPLE}https://<domain-anda>/web/database/manager${NC}"
echo -e "   - Masukkan Master Password di atas untuk membuat database yayasan Anda."
echo -e "   - Setelah database terbuat, proteksi ${CYAN}list_db = False${NC} akan mengunci"
echo -e "     akses publik sehingga database tidak dapat diubah/dihapus sembarangan."
echo ""
echo -e "4. Pemantauan Log & Manajemen:"
echo -e "   - Cek log sistem: ${BLUE}docker compose logs -f${NC}"
echo -e "   - Backup data   : ${BLUE}./scripts/backup.sh${NC}"
echo -e "   - Restore data  : ${BLUE}./scripts/restore.sh backups/<nama_file_backup>.tar.gz${NC}"
echo ""
