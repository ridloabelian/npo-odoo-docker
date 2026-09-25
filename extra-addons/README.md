# Direktori Modul Tambahan Odoo Wakaf (Extra Addons)

Direktori ini di-*mount* langsung ke dalam container Odoo pada path `/mnt/extra-addons`.

## 📦 Struktur Modul Ekosistem Amal Produktif, FWP & ANI

Modul-modul sistem ERP Wakaf hasil kolaborasi Amal Produktif, FWP, dan Asosiasi Nazhir Indonesia (ANI) yang direkomendasikan meliputi:

1. **`waqf_core`**
   - Manajemen Master Data: Profil Nazhir, Data Wakif (Individu & Korporasi), Data Mauquf 'Alaih.
   - Manajemen Legalitas: Akta Ikrar Wakaf (AIW), Akta Pengganti AIW (APAIW), Sertifikasi Tanah & BPN.
   - Standar Kompetensi LSP BWI (Lembaga Sertifikasi Profesi Badan Wakaf Indonesia).

2. **`l10n_id_waqf_psak112`**
   - Bagan Akun Standar Akuntansi Wakaf (COA PSAK 412 / sebelumnya PSAK 112).
   - Laporan Posisi Keuangan Entitas Wakaf (Neraca).
   - Laporan Rincian Aset Wakaf (Aset Wakaf Tidak Bergerak & Bergerak).
   - Laporan Aktivitas Wakaf (Penerimaan, Pengelolaan, dan Penyaluran Manfaat).
   - Laporan Arus Kas Entitas Wakaf.
   - Catatan atas Laporan Keuangan (CALK) otomatis.

3. **`waqf_cash`**
   - Pengelolaan Wakaf Uang & Wakaf Melalui Uang.
   - Integrasi instrumen investasi syariah (Deposito Mudharabah, Cash Waqf Linked Sukuk / CWLS, SBSN).

4. **`waqf_property`**
   - Pengelolaan Aset Wakaf Produktif (Tanah, Ruko, Rumah Sakit, Sekolah, Kebun).
   - Manajemen Kontrak Sewa & Utilisasi Aset.

5. **`waqf_distribution`**
   - Penyaluran Surplus & Hasil Kelolaan Wakaf kepada Mauquf 'Alaih (Asasi & Non-Asasi).
   - Hak Pengelolaan Nazhir (Maksimal 10% sesuai UU No. 41 Tahun 2004).

---

## 🚀 Cara Menambahkan Modul Baru

### Opsi A: Menggunakan Script Otomatis
Jalankan skrip helper yang telah disediakan di root proyek:
```bash
./scripts/download-modules.sh
```

### Opsi B: Kloning Manual via Git
```bash
cd extra-addons
git clone https://github.com/ridloabelian/waqf-odoo-modules.git
```

### Opsi C: Mengunggah Folder Modul Sendiri
Salin folder modul Anda langsung ke dalam folder `extra-addons/` ini. Pastikan folder memiliki file `__manifest__.py` dan `__init__.py`.

---

## 🔄 Aktivasi Modul di Odoo Web UI
1. Masuk ke Odoo sebagai **Administrator**.
2. Buka menu **Settings** -> gulir ke bawah -> klik **Activate the developer mode**.
3. Buka menu **Apps** (Aplikasi).
4. Klik tombol **Update Apps List** pada navigasi atas, lalu konfirmasi.
5. Hapus filter default `"Apps"` di kotak pencarian, lalu ketik nama modul (contoh: `waqf` atau `psak112`).
6. Klik tombol **Activate / Install**.
