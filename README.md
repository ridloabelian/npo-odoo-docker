# npo-odoo-docker: Turnkey Production Package untuk ERP Nirlaba Indonesia

[![Docker](https://img.shields.io/badge/Docker-v2%20Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Odoo](https://img.shields.io/badge/Odoo-19.0%20%7C%2018.0%20LTS-714B67?logo=odoo&logoColor=white)](https://www.odoo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17%20%7C%2016%20Alpine-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Caddy](https://img.shields.io/badge/Caddy-2%20Alpine%20(Auto--SSL)-1F88C0?logo=caddy&logoColor=white)](https://caddyserver.com/)
[![Compliance](https://img.shields.io/badge/Standards-PSAK%20412%20%7C%20PSAK%20109%20%7C%20ISAK%2035-brightgreen)](#standar-dan-regulasi)
[![License](https://img.shields.io/badge/License-LGPL--3.0-blue.svg)](LICENSE)

**`npo-odoo-docker`** adalah repositori instalasi 1-klik (*Turnkey Production Package*) untuk menggelar sistem ERP Odoo 19 / 18 LTS yang telah dioptimasi khusus untuk ekosistem Lembaga Nirlaba, Organisasi Pengelola Zakat (OPZ), Lembaga Pengelola Wakaf (Nazhir), dan Lembaga Kesejahteraan Sosial (LKS/Panti) di Indonesia.

Paket ini dirancang untuk dijalankan di VPS Linux (Ubuntu 22.04 LTS / Ubuntu 24.04 LTS) dengan konfigurasi otomatis multi-worker, auto-swap memory, auto-SSL Let's Encrypt, isolasi jaringan penuh (*zero host exposure*), pencadangan terpadu DB + Filestore, dan disaster recovery 1 perintah.

---

## Daftar Isi
- [Arsitektur Sistem (3-Tier)](#arsitektur-sistem-3-tier)
- [Standar dan Regulasi yang Didukung](#standar-dan-regulasi-yang-didukung)
- [Spesifikasi Server & Hardware](#spesifikasi-server--hardware)
- [Panduan Instalasi Cepat (Quick Start 1-Klik)](#panduan-instalasi-cepat-quick-start-1-klik)
- [Pilihan Profil Sektor Nirlaba](#pilihan-profil-sektor-nirlaba)
- [Tuning Multi-Worker & Alokasi Resource](#tuning-multi-worker--alokasi-resource)
- [Keamanan Produksi & list_db = False](#keamanan-produksi--list_db--false)
- [Operasional: Pencadangan & Pemulihan Bencana](#operasional-pencadangan--pemulihan-bencana)
- [Dukungan Offsite Cloud Backup (Rclone)](#dukungan-offsite-cloud-backup-rclone)
- [Struktur Direktori Repositori](#struktur-direktori-repositori)
- [Troubleshooting & FAQ](#troubleshooting--faq)

---

## Arsitektur Sistem (3-Tier)

Sistem menggunakan Docker Compose v2 dengan pemisahan 3 layer layanan yang terisolasi dalam private bridge network:

```
                            TRAFIK INTERNET (HTTPS / WSS)
                                          │
                                          ▼
                ┌───────────────────────────────────────────────────┐
                │             LAYER 1: REVERSE PROXY                │
                │                (Caddy 2 Alpine)                   │
                │   - Port Publik: 80 (HTTP) & 443 (HTTPS/QUIC)     │
                │   - Otomasi Sertifikat SSL/TLS Let's Encrypt      │
                │   - HTTP/3 QUIC Support & HSTS Hardening          │
                └─────────────────┬───────────────┬─────────────────┘
                                  │               │
                     Trafik Web   │               │ WebSocket & Bus
                     (Port 8069)  │               │ (Port 8072)
                                  ▼               ▼
                ┌───────────────────────────────────────────────────┐
                │              LAYER 2: APPLICATION                │
                │            (Odoo 19.0 / 18.0 LTS)                 │
                │   - Multi-Worker Tuning: (Cores * 2) + 1          │
                │   - Pustaka: openpyxl, qrcode, num2words          │
                │   - Port 8069 & 8072 ISOLASI INTERNAL (Zero Host) │
                └─────────────────────────┬─────────────────────────┘
                                          │
                                          │ Koneksi Database Internal
                                          │ (Port 5432 - Tanpa Port Host)
                                          ▼
                ┌───────────────────────────────────────────────────┐
                │               LAYER 3: DATABASE                   │
                │         (PostgreSQL 17 / 16 Alpine)               │
                │   - Buffer Tuning: shared_buffers 256MB+          │
                │   - Healthcheck: pg_isready                       │
                │   - ZERO HOST EXPOSURE (Tidak terbuka ke publik)  │
                └───────────────────────────────────────────────────┘
```

---

## Standar dan Regulasi yang Didukung

| Sektor Nirlaba | Regulasi / Standar Akuntansi | Regulator / Otoritas Pembina |
| :--- | :--- | :--- |
| **Sektor Wakaf** | **PSAK 412** (Sebelumnya PSAK 112) & Standar LSP BWI | Badan Wakaf Indonesia (BWI) & Kemenag RI |
| **Sektor Zakat & Donasi** | **PSAK 109** (Akuntansi ZIS) & Standar BAZNAS | Badan Amil Zakat Nasional (BAZNAS) & Kemenag RI |
| **Sektor LKS / Panti Sosial** | **ISAK 35** (Penyajian Lapkeu Nonlaba) & BALAKS | Kementerian Sosial RI (Kemensos) |
| **Master Data Terpadu** | NIK, KK, NPWP 16 Digit, NIB, Kode Wilayah Kemendagri | Kemendagri, Ditjen Pajak, BKPM |

---

## Spesifikasi Server & Hardware

| Parameter | Kebutuhan Minimum (VPS Kecil) | Rekomendasi Produksi (VPS Menengah) |
| :--- | :--- | :--- |
| **Sistem Operasi** | Ubuntu 22.04 LTS / Ubuntu 24.04 LTS | Ubuntu 22.04 LTS / 24.04 LTS / Debian 12 |
| **CPU Core** | 2 vCPU Core | 4 vCPU Core atau lebih |
| **RAM Fisik** | 4 GB | 8 GB s/d 16 GB |
| **Swap Memory** | **2 GB** (dibuat otomatis oleh skrip) | 2 GB s/d 4 GB |
| **Storage (Disk)** | 40 GB NVMe / SSD | 100 GB+ NVMe SSD |
| **Port Publik** | 80/TCP, 443/TCP, 443/UDP | 80/TCP, 443/TCP, 443/UDP |

> [!NOTE]
> Jika VPS Anda memiliki RAM kurang dari 8 GB, skrip `init-setup.sh` akan secara otomatis membuat dan mengaktifkan **Swap File 2 GB** (`/swapfile`) dengan prioritas swap ramah RAM (`vm.swappiness=10`) untuk mencegah proses Odoo terhenti karena *Out-Of-Memory* (OOM Killer).

---

## Panduan Instalasi Cepat (Quick Start 1-Klik)

### Langkah 1: Kloning Repositori di VPS

Masuk ke server VPS Linux Anda melalui SSH, lalu unduh repositori ini:

```bash
git clone https://github.com/ridloabelian/waqf-odoo-docker.git npo-odoo-docker
cd npo-odoo-docker
```

### Langkah 2: Berikan Izin Eksekusi & Jalankan Setup Wizard

Jalankan wizard interaktif sebagai `root` atau pengguna berhak `sudo`:

```bash
chmod +x init-setup.sh scripts/*.sh
sudo ./init-setup.sh
```

### Langkah 3: Pilih Profil Sistem Nirlaba Anda

Wizard akan menyajikan menu interaktif di terminal:

```text
----------------------------------------------------------------------
Pilih Profil Sistem Nirlaba Anda:
[1] Sektor Wakaf (Badan Wakaf Indonesia - PSAK 412)
    -> Mengunduh: npo-core-modules + waqf-odoo-modules
[2] Sektor Zakat & Donasi (BAZNAS - PSAK 109)
    -> Mengunduh: npo-core-modules + zakat-odoo-modules
[3] Sektor Lembaga Kesejahteraan Sosial / Panti (Kemensos - ISAK 35)
    -> Mengunduh: npo-core-modules + lks-odoo-modules
[4] Yayasan Terpadu / All-in-One (Wakaf + Zakat + LKS)
    -> Mengunduh seluruh ekosistem modul ke ./extra-addons
----------------------------------------------------------------------
Masukkan pilihan profil [1/2/3/4] (default: 1):
```

Skrip akan secara otomatis:
1. Memeriksa Docker & Docker Compose v2.
2. Mengonfigurasi Swap File 2 GB jika RAM < 8 GB.
3. Mengunduh dan menata modul Odoo sesuai profil yang dipilih.
4. Men-generate password acak berkekuatan tinggi untuk Database PostgreSQL & Odoo Master Admin ke `.env`.
5. Mengompilasi `config/odoo.conf` dengan `addons_path` yang sesuai dan proteksi produksi `list_db = False`.

### Langkah 4: Sesuaikan Nama Domain & Email SSL

Buka file konfigurasi `.env`:

```bash
nano .env
```

Ubah dua variabel berikut:
```ini
DOMAIN_NAME=erp.yayasananda.or.id
ACME_EMAIL=admin@yayasananda.or.id
```
*(Pastikan DNS A Record domain Anda sudah diarahkan ke IP publik VPS).*

### Langkah 5: Nyalakan Seluruh Layanan dengan Docker Compose

```bash
docker compose up -d
```

Pantau proses *startup*:
```bash
docker compose logs -f
```

### Langkah 6: Pembuatan Database Pertama Kali

1. Buka browser dan kunjungi:
   ```text
   https://erp.yayasananda.or.id/web/database/manager
   ```
2. Masukkan **Master Password** yang telah digenerate di file `.env` (lihat baris `ADMIN_PASSWORD=...`).
3. Buat database baru (misalnya `npo_production`), pilih bahasa **Indonesian (ID)**, dan centang atau hilangkan data demo sesuai kebutuhan.
4. Setelah database selesai dibuat, sistem akan langsung terkunci aman karena proteksi `list_db = False`.

---

## Pilihan Profil Sektor Nirlaba

### Profil 1: Sektor Wakaf (BWI - PSAK 412 / 112)
Dikhususkan untuk Badan Wakaf Indonesia (BWI), Nazhir Perorangan, Nazhir Organisasi, dan Nazhir Badan Hukum.
- **npo-core-modules**: Master data identitas (NIK/KK), kode wilayah Kemendagri, engine asesmen, modul penyaluran dasar.
- **waqf-odoo-modules**:
  - `waqf_core`: Pendaftaran wakif, jenis wakaf (uang, aset bergerak, tidak bergerak), Akta Ikrar Wakaf (AIW), Sertifikat Wakaf.
  - `l10n_id_waqf_psak112`: Bagan Akun Standar (COA) Wakaf, Neraca, Laporan Rincian Aset Wakaf, Laporan Aktivitas, Perubahan Aset Neto, dan Hak Nazhir 10%.
  - `waqf_asset_management`: Inventarisasi tanah wakaf, sertifikasi BPN, status produktif tanah/bangunan, peta koordinat GPS.
  - `waqf_distribution`: Penyaluran hasil pengelolaan wakaf kepada Mauquf 'Alaih (penerima manfaat wakaf).

### Profil 2: Sektor Zakat & Donasi (BAZNAS - PSAK 109)
Dikhususkan untuk BAZNAS Provinsi/Kabupaten/Kota, Lembaga Amil Zakat (LAZ Nasional/Daerah), dan Unit Pengumpul Zakat (UPZ).
- **npo-core-modules**: Identitas muzakki/mustahik terpadu, verifikasi kependudukan.
- **zakat-odoo-modules**:
  - `zakat_core`: Manajemen Muzakki, Mustahik (8 Asnaf BAZNAS), dan Kalkulator Nisab otomatis (Zakat Maal, Profesi, Fitrah, Pertanian).
  - `l10n_id_zakat_psak109`: Bagan Akun Standar (COA) Dana Zakat, Dana Infak/Sedekah, Dana Amil, dan Dana Non-Halal, Laporan Perubahan Dana PSAK 109.
  - `zakat_collection`: Penerimaan ZIS, penerbitan Bukti Setor Zakat (BSZ) resmi ber-QR Code untuk pengurangan pajak penghasilan.
  - `zakat_distribution`: Penyaluran dana 8 asnaf (Program Konsumtif & Produktif pemberdayaan ekonomi).

### Profil 3: Sektor Lembaga Kesejahteraan Sosial / Panti (Kemensos - ISAK 35)
Dikhususkan untuk Panti Asuhan, Panti Werda/Lansia, Panti Rehabilitasi Disabilitas, dan LKS mitra Kemensos RI.
- **npo-core-modules**: Basis data penerima manfaat dan riwayat bantuan.
- **lks-odoo-modules**:
  - `lks_core`: Registrasi Pemerlu Pelayanan Kesejahteraan Sosial (PPKS), Buku Induk Panti, kapasitas asrama/kamar.
  - `l10n_id_nonprofit_isak35`: Akuntansi entitas berorientasi nonlaba ISAK 35 (Laporan Posisi Keuangan, Penghasilan Komprehensif, Arus Kas).
  - `lks_social_care`: Asuhan sosial klaster anak, lansia, disabilitas, monitoring tumbuh kembang dan rekam medis sosial.
  - `lks_balaks_compliance`: Standar instrumen akreditasi Badan Akreditasi Lembaga Kesejahteraan Sosial (BALAKS) Kemensos RI.

### Profil 4: Yayasan Terpadu / All-in-One (Wakaf + Zakat + LKS)
Mengintegrasikan seluruh ekosistem modul nirlaba dalam satu instalasi Odoo untuk organisasi induk atau yayasan filantropi berskala nasional yang mengelola program wakaf, penghimpunan zakat, serta operasional panti asuhan secara bersamaan.

---

## Tuning Multi-Worker & Alokasi Resource

Odoo dalam mode multi-worker memisahkan proses penanganan HTTP request dan proses komputasi berat (cron & longpolling).

### 1. Rumus Perhitungan Worker Ideal:
$$\text{Workers} = (\text{CPU Cores} \times 2) + 1$$

Contoh rekomendasi:
- **VPS 2 vCPU**: `ODOO_WORKERS=4` atau `5`
- **VPS 4 vCPU**: `ODOO_WORKERS=8` atau `9`
- **VPS 8 vCPU**: `ODOO_WORKERS=17`

### 2. Parameter Memori & Timeout di `.env` & `odoo.conf`:
```ini
# Batas RAM per worker (2 GB Soft / 2.5 GB Hard)
ODOO_LIMIT_MEMORY_SOFT=2147483648
ODOO_LIMIT_MEMORY_HARD=2684354560

# Timeout komputasi diperpanjang untuk laporan keuangan akuntansi nirlaba yang tebal
ODOO_LIMIT_TIME_CPU=600
ODOO_LIMIT_TIME_REAL=1200

# Worker didaur ulang setiap 8.192 request untuk mencegah memory leak Python
limit_request = 8192
```

### 3. Tuning Buffer PostgreSQL (`command:` di docker-compose.yml):
PostgreSQL disetel dengan konfigurasi performa tinggi untuk VPS 4 GB - 16 GB:
- `shared_buffers = 256MB` s/d `1GB` (25% dari RAM)
- `effective_cache_size = 768MB` s/d `3GB` (75% dari RAM)
- `work_mem = 16MB`
- `maintenance_work_mem = 64MB`
- `checkpoint_completion_target = 0.9`

---

## Keamanan Produksi & list_db = False

Pada lingkungan produksi perbankan syariah dan lembaga publik, antarmuka pembuat database (`/web/database/manager` dan `/web/database/selector`) **wajib dikunci** dari akses publik untuk mencegah:
1. Pihak luar mengetahui nama database yayasan Anda (*database enumeration*).
2. Serangan *brute force* terhadap Master Password.
3. Pembuatan database palsu yang membebani disk VPS.

### Konfigurasi Proteksi `list_db = False`:
File `config/odoo.conf` secara baku disetel:
```ini
list_db = False
```

### Prosedur Manajemen Database:
- **Membuat Database Pertama Kali**:
  Akses langsung URL lengkap: `https://<domain-anda>/web/database/manager`. Masukkan Master Password dari `.env`.
- **Mengunci Sistem Kembali (Production Lock)**:
  Cukup jalankan satu perintah:
  ```bash
  ./scripts/lock-production.sh
  ```
  Skrip ini akan memastikan `list_db = False` aktif dan merestart container Odoo web secara *graceful*.

---

## Operasional: Pencadangan & Pemulihan Bencana

### 1. Pencadangan Otomatis (`scripts/backup.sh`)
Skrip ini mengekspor Database PostgreSQL (`pg_dump` dikompresi `gzip`) dan seluruh berkas fisik Odoo Filestore (`/var/lib/odoo/filestore`), lalu mengemasnya menjadi arsip tunggal berstempel waktu: `npo_backup_YYYYMMDD_HHMMSS.tar.gz`.

Jalankan manual:
```bash
./scripts/backup.sh
```

#### Otomasi via Cron Job Linux:
Jadwalkan pencadangan setiap hari pukul 02.00 dini hari dengan retensi lokal 7 hari:
```bash
crontab -e
```
Tambahkan baris berikut di baris paling bawah:
```cron
0 2 * * * cd /root/npo-odoo-docker && ./scripts/backup.sh >> /var/log/npo_backup.log 2>&1
```

### 2. Pemulihan Bencana 1-Perintah (`scripts/restore.sh`)
Jika terjadi kerusakan sistem, *human error*, atau Anda memindahkan data ke VPS baru:

```bash
./scripts/restore.sh backups/npo_backup_YYYYMMDD_HHMMSS.tar.gz
```
Skrip akan:
1. Meminta konfirmasi pengetikan kata `YA`.
2. Menghentikan service web Odoo sementara.
3. Me-reset dan memulihkan seluruh struktur tabel & isi PostgreSQL.
4. Memulihkan seluruh berkas attachment di Filestore.
5. Menyalakan kembali service web Odoo.

---

## Dukungan Offsite Cloud Backup (Rclone)

Untuk mencegah kehilangan data jika VPS terbakar atau terjadi insiden di datacenter penyedia hosting, sistem mendukung sinkronisasi otomatis ke penyimpanan cloud offsite menggunakan **Rclone** (Google Drive, AWS S3, Cloudflare R2, MinIO, atau Wasabi).

### Cara Mengaktifkan:
1. Pasang rclone di VPS:
   ```bash
   sudo apt-get install -y rclone
   ```
2. Hubungkan akun cloud Anda:
   ```bash
   rclone config
   ```
   *(Beri nama remote, misalnya: `gdrive_yayasan`)*.
3. Masukkan nama remote tersebut ke file `.env`:
   ```ini
   RCLONE_REMOTE=gdrive_yayasan
   RCLONE_DEST_PATH=OdooBackups/NPO
   ```
4. Setiap kali `./scripts/backup.sh` berjalan, arsip cadangan akan otomatis diunggah ke cloud dan file cadangan di cloud yang lebih tua dari `BACKUP_RETENTION_DAYS` (7 hari) akan otomatis dibersihkan.

---

## Struktur Direktori Repositori

```text
npo-odoo-docker/
├── .env.example                # Template konfigurasi variabel lingkungan
├── .env                        # File konfigurasi aktif (kredensial & domain)
├── Dockerfile                  # Odoo 19/18 image dengan dependensi Python lengkap
├── docker-compose.yml          # Konfigurasi 3-tier: Caddy, Odoo Web, PostgreSQL
├── init-setup.sh               # Wizard 1-klik instalasi, swap tuning & modul selector
├── README.md                   # Dokumentasi teknis & panduan instalasi
├── config/
│   ├── Caddyfile               # Aturan Reverse Proxy, Auto-SSL & WebSocket 8072
│   ├── odoo.conf.template      # Template konfigurasi Odoo produksi
│   └── odoo.conf               # Konfigurasi aktif Odoo
├── scripts/
│   ├── backup.sh               # Otomasi backup harian DB + Filestore (+ Rclone)
│   ├── restore.sh              # Skrip pemulihan bencana (Disaster Recovery) 1-klik
│   ├── lock-production.sh      # Skrip penguncian keamanan list_db = False
│   └── download-modules.sh     # Utilitas pembaruan modul sektor nirlaba
├── extra-addons/               # Volume addons yang dimounting ke dalam container
├── npo-core-modules/           # Modul inti NPO (Kependudukan, Asesmen, Penyaluran)
├── waqf-odoo-modules/          # Ekosistem Modul Sektor Wakaf (BWI & PSAK 412)
├── zakat-odoo-modules/         # Ekosistem Modul Sektor Zakat (BAZNAS & PSAK 109)
├── lks-odoo-modules/           # Ekosistem Modul Sektor LKS/Panti (Kemensos & ISAK 35)
└── backups/                    # Lokasi penyimpanan arsip cadangan lokal (.tar.gz)
```

---

## Troubleshooting & FAQ

### 1. Port 80 atau 443 sudah digunakan (*Bind address already in use*)
Penyebab: VPS Anda sudah menjalankan Apache atau Nginx bawaan OS.
Solusi: Hentikan dan nonaktifkan web server bawaan tersebut:
```bash
sudo systemctl stop apache2 nginx 2>/dev/null || true
sudo systemctl disable apache2 nginx 2>/dev/null || true
docker compose restart proxy
```

### 2. Sertifikat SSL Let's Encrypt Gagal Dibuat
Penyebab: DNS A Record domain Anda belum mengarah ke IP publik VPS, atau firewall VPS menutup port 80/443.
Solusi:
1. Pastikan `ping <nama-domain>` menghasilkan IP VPS Anda.
2. Buka firewall UFW:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 443/udp
   ```
3. Periksa log Caddy:
   ```bash
   docker compose logs proxy
   ```

### 3. Mengubah Profil Instalasi Setelah Deploy
Jika Anda awalnya memilih Profil 1 (Wakaf) lalu ingin beralih ke Profil 4 (All-in-One):
1. Jalankan kembali:
   ```bash
   ./init-setup.sh --profile 4
   ```
2. Restart container web:
   ```bash
   docker compose restart web
   ```
3. Buka Odoo -> Aktifkan Developer Mode -> Apps -> Update Apps List.

### 4. Perintah Operasional Docker yang Sering Digunakan
- **Melihat status container**: `docker compose ps`
- **Melihat log real-time**: `docker compose logs -f`
- **Melihat log Odoo saja**: `docker compose logs -f web`
- **Restart layanan Odoo**: `docker compose restart web`
- **Menghentikan seluruh sistem**: `docker compose down`
- **Menyalakan kembali**: `docker compose up -d`

---

## Kontribusi & Lisensi

Inisiatif repositori ini dikembangkan secara terbuka untuk memodernisasi tata kelola teknologi informasi organisasi nirlaba, wakaf, dan zakat di Indonesia.

- **Lisensi**: GNU Lesser General Public License v3.0 (LGPL-3.0)
- **Kompatibilitas**: Odoo 19.0 Community, Odoo 18.0 LTS Community, Odoo Enterprise.
