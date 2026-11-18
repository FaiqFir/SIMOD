<?php
// index.php — halaman cek cepat. Taruh di folder root site (yang berisi folder apkdepot_api).
// Buka: http://apkdepot.test/   -> menampilkan status PHP, ekstensi, dan koneksi database.
header('Content-Type: application/json; charset=utf-8');

$hasil = [
    'aplikasi' => 'MOD API',
    'php' => PHP_VERSION,
    'pdo_mysql' => extension_loaded('pdo_mysql'),
];

$koneksi = is_file(__DIR__ . '/apkdepot_api/koneksi.php') ? __DIR__ . '/apkdepot_api/koneksi.php'
    : (is_file(__DIR__ . '/koneksi.php') ? __DIR__ . '/koneksi.php' : null);

if ($koneksi === null) {
    $hasil['database'] = 'koneksi.php tidak ditemukan';
} elseif (!$hasil['pdo_mysql']) {
    $hasil['database'] = 'ekstensi pdo_mysql belum aktif di PHP';
} else {
    require_once $koneksi;   // kalau gagal konek, koneksi.php sendiri membalas pesan error
    db()->query('SELECT 1');
    $hasil['database'] = 'terhubung ke ' . DB_NAMA;
}

echo json_encode($hasil, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
