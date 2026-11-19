# SIMOD — Sistem Informasi Manajemen Operasional Depot

Aplikasi mobile (Flutter) + backend PHP/MySQL untuk manajemen depot air minum.

## Fitur Utama
- **Produk**: Kelola 5 jenis produk (Jenis Air, Galon Kosong, Galon Kosong+Isi, Es, Sparepart)
- **Transaksi**: 9 jenis aksi (Isi Ulang, Beli Galon, Beli Galon+Isi, Beli Es, Pinjam Galon+Isi, Pengeluaran, Pendapatan Lain, Ganti Sparepart, Kembali Galon)
- **Stok & Peminjam**: Tracking stok real-time + daftar peminjam galon
- **Laporan**: Harian, Mingguan, Bulanan, Tahunan + ekspor CSV
- **Pengingat**: Otomatis untuk stok menipis & sparepart jatuh tempo

## Anggota Kelompok 4
| Nama | NIM |
|------|-----|
| Faiq Muhammad | F5512510001 |
| Cindy Novita Auliyah | F5512510021 |
| Zaskia Dian Amanda | F5512510031 |

## Struktur Project
```
apkdepot/
├── apkdepot_api/      # Backend PHP (auth, produk, transaksi, laporan)
├── apkdepot_app/      # Flutter app
├── apkdepot.sql       # Skema database
└── index.php          # Health check endpoint
```

## Quick Start
1. Import `apkdepot.sql` ke MySQL/MariaDB
2. Sesuaikan `DB_*` di `apkdepot_api/koneksi.php`
3. Jalankan PHP server (Laragon/XAMPP) di port 8000
4. `flutter pub get` di folder `apkdepot_app`
5. `flutter run` (emulator Android: gunakan `10.0.2.2` untuk akses localhost)

## Teknologi
- **Frontend**: Flutter 3.x, Dart 3.x, Material 3
- **Backend**: PHP 8.x (PDO), MySQL/MariaDB
- **Auth**: Session-based (id_depot per request), SecureStorage
- **State**: setState + ChangeNotifier (ProfileImageService)