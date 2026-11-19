<?php
// Halaman cek cepat: status PHP, ekstensi, dan koneksi database.
// Taruh di root site (folder yang berisi apkdepot_api).
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
    require_once $koneksi;   // koneksi.php membalas pesan error sendiri bila gagal
    db()->query('SELECT 1');
    $hasil['database'] = 'terhubung ke ' . DB_NAMA;
}

echo json_encode($hasil, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
