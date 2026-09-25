# ==============================================================================
# DOCKERFILE - ODOO 19 / 18 LTS PRODUCTION FOR INDONESIAN NPO ECOSYSTEM
# Standar Akuntansi: PSAK 412 (Wakaf), PSAK 109 (Zakat), ISAK 35 (Sosial/LKS)
# ==============================================================================
# Base image resmi Odoo (default: 19.0, dapat dioverride ke 18.0)
ARG ODOO_BASE_IMAGE=odoo:19.0
FROM ${ODOO_BASE_IMAGE}

LABEL maintainer="Tim Pengembang NPO Odoo Indonesia <dev@npo.id>"
LABEL description="Odoo 19/18 Community Edition dengan dependensi Python lengkap untuk Lembaga Nirlaba Indonesia (PSAK 412, PSAK 109, ISAK 35)"

USER root

# Pasang paket sistem Debian yang diperlukan untuk kompilasi C, manipulasi XML/PDF, dan utilitas
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libffi-dev \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Pasang pustaka Python penting untuk ekosistem ERP Nirlaba Indonesia:
# - num2words: Konversi angka nominal ke huruf terbilang Rupiah pada Akta Ikrar Wakaf, Bukti Setor Zakat (BSZ) & Kuitansi Donasi
# - openpyxl & xlsxwriter: Ekspor laporan keuangan PSAK 412 / PSAK 109 / ISAK 35 (Neraca, Posisi Keuangan, Arus Kas, Perubahan Aset Neto) ke Excel
# - qrcode[pil]: Pembuatan QR Code verifikasi keaslian Sertifikat Wakaf BWI, BSZ BAZNAS & Bukti Penerimaan Donasi
# - phonenumbers: Format dan validasi nomor telepon/WhatsApp wakif, muzakki, donatur, dan mustahik di Indonesia
# - cryptography: Kebutuhan keamanan enkripsi data dan integrasi API
RUN pip3 install --no-cache-dir --break-system-packages \
    num2words \
    openpyxl \
    xlsxwriter \
    "qrcode[pil]" \
    phonenumbers \
    cryptography

# Buat direktori kustom addons jika belum ada dan pastikan kepemilikan oleh user odoo
RUN mkdir -p /mnt/extra-addons && chown -R odoo:odoo /mnt/extra-addons

# Kembalikan user ke non-root 'odoo' demi keamanan produksi (least privilege)
USER odoo

EXPOSE 8069 8072
