<?php
// koneksi.php — koneksi database + fungsi pembantu yang dipakai semua file
// Taruh di folder yang sama dengan file API lain.

// Pengaturan database
const DB_HOST = '127.0.0.1';
const DB_NAMA = 'apkdepot';
const DB_USER = 'depot';
const DB_PASS = 'depot123';

// WITA — disamakan dengan time_zone MySQL
date_default_timezone_set('Asia/Makassar');

// Error PHP tidak ditampilkan agar balasan JSON tetap valid
ini_set('display_errors', '0');
error_reporting(E_ALL);

// CORS untuk Flutter Web
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Balasan JSON: sukses {"status":"sukses","data":...} | gagal {"status":"error","message":"..."}
function kirimJson($payload, int $kode = 200): void
{
    if (!headers_sent()) {
        http_response_code($kode);
        header('Content-Type: application/json; charset=utf-8');
    }
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PARTIAL_OUTPUT_ON_ERROR);
    exit;
}

function sukses($data = null): void
{
    kirimJson(['status' => 'sukses', 'data' => $data]);
}

function gagal(string $pesan, int $kode = 400): void
{
    kirimJson(['status' => 'error', 'message' => $pesan], $kode);
}

// Exception khusus: pesan boleh langsung ditampilkan ke pengguna
class AppError extends Exception
{
}

// Tangkap semua error tak terduga -> tetap balas JSON yang valid
set_exception_handler(function (Throwable $e) {
    if ($e instanceof AppError) {
        gagal($e->getMessage());
    }
    error_log('[apkdepot] ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    gagal('Terjadi kesalahan pada server. Cek log PHP / pastikan database "' . DB_NAMA . '" sudah diimpor.', 500);
});

// Koneksi PDO (satu koneksi per permintaan)
function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
                'mysql:host=' . DB_HOST . ';dbname=' . DB_NAMA . ';charset=utf8mb4',
                DB_USER,
                DB_PASS,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                ]
            );
            $pdo->exec("SET time_zone = '+08:00'");
        } catch (PDOException $e) {
            error_log('[apkdepot] koneksi gagal: ' . $e->getMessage());
            gagal('Tidak bisa terhubung ke database. Pastikan MySQL di Laragon menyala dan database "' . DB_NAMA . '" sudah dibuat.', 500);
        }
    }
    return $pdo;
}

// Fungsi pembantu umum

/** UUID v4 untuk kolom id CHAR(36) */
function uuid(): string
{
    $b = random_bytes(16);
    $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
    $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
}

/** Ambil nilai input (POST lalu GET). Kosong -> $bawaan. */
function input(string $kunci, $bawaan = null)
{
    $v = $_POST[$kunci] ?? $_GET[$kunci] ?? null;
    if ($v === null) {
        return $bawaan;
    }
    if (is_string($v)) {
        $v = trim($v);
        if ($v === '') {
            return $bawaan;
        }
    }
    return $v;
}

/** Input wajib: kalau kosong, tolak dengan pesan */
function wajib(string $kunci, string $label)
{
    $v = input($kunci);
    if ($v === null) {
        throw new AppError("$label wajib diisi.");
    }
    return $v;
}

/** Angka bulat positif/nol dari input, atau tolak */
function inputInt(string $kunci, string $label, int $min = 0): int
{
    $v = wajib($kunci, $label);
    if (!is_numeric($v) || (float)$v != (int)(float)$v) {
        throw new AppError("$label harus berupa bilangan bulat.");
    }
    $n = (int)(float)$v;
    if ($n < $min) {
        throw new AppError("$label minimal $min.");
    }
    return $n;
}

/** Angka desimal dari input (menerima "5000", "5000.50"), atau tolak */
function inputUang(string $kunci, string $label, bool $harusPositif = true): float
{
    $v = wajib($kunci, $label);
    if (!is_numeric($v)) {
        throw new AppError("$label harus berupa angka.");
    }
    $n = (float)$v;
    if ($harusPositif && $n <= 0) {
        throw new AppError("$label harus lebih dari 0.");
    }
    if ($n < 0) {
        throw new AppError("$label tidak boleh negatif.");
    }
    return $n;
}

/** Validasi tanggal yyyy-MM-dd; kembalikan string yang sama */
function cekTanggal(?string $t, string $label = 'Tanggal'): string
{
    if ($t === null || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $t)) {
        throw new AppError("$label harus berformat yyyy-MM-dd.");
    }
    [$y, $m, $d] = array_map('intval', explode('-', $t));
    if (!checkdate($m, $d, $y)) {
        throw new AppError("$label tidak valid.");
    }
    return $t;
}

/** Validasi jam HH:mm (atau HH:mm:ss) -> kembalikan HH:mm:ss */
function cekJam(?string $j, string $label): string
{
    if ($j === null || !preg_match('/^([01]?\d|2[0-3]):([0-5]\d)(:([0-5]\d))?$/', $j)) {
        throw new AppError("$label harus berformat HH:mm.");
    }
    $p = explode(':', $j);
    return sprintf('%02d:%02d:%02d', (int)$p[0], (int)$p[1], (int)($p[2] ?? 0));
}

/** Pastikan id_depot valid. Mengembalikan id_depot. */
function depotAktif(): string
{
    $id = input('id_depot');
    if ($id === null) {
        throw new AppError('Sesi tidak valid. Silakan login ulang.');
    }
    $st = db()->prepare('SELECT id FROM depot WHERE id = ?');
    $st->execute([$id]);
    if (!$st->fetch()) {
        throw new AppError('Depot tidak ditemukan. Silakan login ulang.');
    }
    return $id;
}

/** Baris depot dalam bentuk yang dibaca DepotModel.fromJson (jam 'HH:mm') */
function depotJson(string $idDepot): array
{
    $st = db()->prepare(
        "SELECT id, nama_depot, alamat,
                TIME_FORMAT(jam_buka, '%H:%i') AS jam_buka,
                TIME_FORMAT(jam_tutup, '%H:%i') AS jam_tutup,
                notifikasi_stok_menipis, notifikasi_sparepart
         FROM depot WHERE id = ?"
    );
    $st->execute([$idDepot]);
    $d = $st->fetch();
    if (!$d) {
        throw new AppError('Depot tidak ditemukan.');
    }
    $d['notifikasi_stok_menipis'] = (int)$d['notifikasi_stok_menipis'];
    $d['notifikasi_sparepart'] = (int)$d['notifikasi_sparepart'];
    return $d;
}

/** Aksi yang diminta (?aksi=...) */
function aksi(): string
{
    $a = input('aksi');
    if ($a === null) {
        throw new AppError('Parameter "aksi" tidak ada.');
    }
    return (string)$a;
}

// Pengingat stok menipis & sparepart jatuh tempo.
// Sesuai toggle notifikasi di Profil; pengingat yang sudah beres ditandai 'selesai'.
function periksaPengingat(string $idDepot): void
{
    $pdo = db();
    $depot = $pdo->prepare('SELECT notifikasi_stok_menipis, notifikasi_sparepart FROM depot WHERE id = ?');
    $depot->execute([$idDepot]);
    $set = $depot->fetch();
    if (!$set) {
        return;
    }

    $adaTerbuka = $pdo->prepare(
        "SELECT 1 FROM pengingat
         WHERE id_depot = ? AND id_produk = ? AND jenis = ? AND status IN ('belum_dibaca','dibaca') LIMIT 1"
    );
    $buat = $pdo->prepare(
        'INSERT INTO pengingat (id, id_depot, jenis, id_produk, pesan) VALUES (?,?,?,?,?)'
    );
    $selesaikan = $pdo->prepare(
        "UPDATE pengingat SET status = 'selesai'
         WHERE id_depot = ? AND id_produk = ? AND jenis = ? AND status <> 'selesai'"
    );

    // ---- stok menipis ----
    $stokList = $pdo->prepare(
        "SELECT p.id, p.nama_produk, p.ambang_stok_minimum, COALESCE(s.jumlah_saat_ini, 0) AS jumlah
         FROM produk p LEFT JOIN stok s ON s.id_produk = p.id
         WHERE p.id_depot = ? AND p.aktif = 1 AND p.jenis IN ('galon_kosong','es')"
    );
    $stokList->execute([$idDepot]);
    foreach ($stokList->fetchAll() as $p) {
        $ambang = $p['ambang_stok_minimum'] !== null ? (int)$p['ambang_stok_minimum'] : 5;
        $jumlah = (int)$p['jumlah'];
        if ($jumlah <= $ambang) {
            if ((int)$set['notifikasi_stok_menipis'] === 1) {
                $adaTerbuka->execute([$idDepot, $p['id'], 'stok_menipis']);
                if (!$adaTerbuka->fetch()) {
                    $buat->execute([
                        uuid(), $idDepot, 'stok_menipis', $p['id'],
                        "Stok {$p['nama_produk']} tinggal $jumlah (batas minimum $ambang).",
                    ]);
                }
            }
        } else {
            $selesaikan->execute([$idDepot, $p['id'], 'stok_menipis']);
        }
    }

    // ---- sparepart mendekati / lewat waktu ganti ----
    $spare = $pdo->prepare(
        "SELECT id, nama_produk, masa_pakai_hari, terakhir_diganti
         FROM produk
         WHERE id_depot = ? AND aktif = 1 AND jenis = 'sparepart'
           AND masa_pakai_hari IS NOT NULL AND terakhir_diganti IS NOT NULL"
    );
    $spare->execute([$idDepot]);
    $hariIni = new DateTimeImmutable('today');
    foreach ($spare->fetchAll() as $p) {
        $jatuhTempo = (new DateTimeImmutable($p['terakhir_diganti']))
            ->modify('+' . (int)$p['masa_pakai_hari'] . ' days');
        $batasPeringatan = $jatuhTempo->modify('-7 days');
        if ($hariIni >= $batasPeringatan) {
            if ((int)$set['notifikasi_sparepart'] === 1) {
                $adaTerbuka->execute([$idDepot, $p['id'], 'sparepart_jatuh_tempo']);
                if (!$adaTerbuka->fetch()) {
                    $selisih = (int)$hariIni->diff($jatuhTempo)->format('%r%a');
                    if ($selisih > 0) {
                        $pesan = "{$p['nama_produk']} perlu diganti dalam $selisih hari (" . $jatuhTempo->format('d/m/Y') . ').';
                    } elseif ($selisih === 0) {
                        $pesan = "{$p['nama_produk']} jatuh tempo diganti hari ini.";
                    } else {
                        $pesan = "{$p['nama_produk']} sudah lewat " . abs($selisih) . ' hari dari jadwal ganti (' . $jatuhTempo->format('d/m/Y') . ').';
                    }
                    $buat->execute([uuid(), $idDepot, 'sparepart_jatuh_tempo', $p['id'], $pesan]);
                }
            }
        } else {
            $selesaikan->execute([$idDepot, $p['id'], 'sparepart_jatuh_tempo']);
        }
    }
}

/** Daftar pengingat sesuai toggle di Profil. $status kosong = semua status. */
function daftarPengingatJson(string $idDepot, ?string $status = null, bool $hanyaTerbuka = false): array
{
    $sql = "SELECT g.id, g.jenis, g.id_produk, p.nama_produk, g.pesan, g.status, g.dibuat_pada
            FROM pengingat g
            JOIN produk p ON p.id = g.id_produk
            JOIN depot d ON d.id = g.id_depot
            WHERE g.id_depot = ? AND p.aktif = 1
              AND (g.jenis <> 'stok_menipis' OR d.notifikasi_stok_menipis = 1)
              AND (g.jenis <> 'sparepart_jatuh_tempo' OR d.notifikasi_sparepart = 1)";
    $par = [$idDepot];
    if ($status !== null) {
        if (!in_array($status, ['belum_dibaca', 'dibaca', 'selesai'], true)) {
            throw new AppError('Status pengingat tidak valid.');
        }
        $sql .= ' AND g.status = ?';
        $par[] = $status;
    } elseif ($hanyaTerbuka) {
        $sql .= " AND g.status <> 'selesai'";
    }
    $sql .= ' ORDER BY g.dibuat_pada DESC';
    $st = db()->prepare($sql);
    $st->execute($par);
    return $st->fetchAll();
}

// Stok — satu-satunya pintu mengubah angka stok.
// Dipanggil di dalam transaksi database; stok tidak boleh minus dan
// setiap perubahan dicatat di pergerakan_stok.
// Mengembalikan jumlah stok setelah perubahan.
function ubahStok(string $idProduk, int $perubahan, ?string $idTransaksi, string $jenisPergerakan, ?string $keterangan = null): int
{
    $pdo = db();
    $st = $pdo->prepare(
        'SELECT p.nama_produk, s.id AS id_stok, COALESCE(s.jumlah_saat_ini, 0) AS jumlah
         FROM produk p LEFT JOIN stok s ON s.id_produk = p.id
         WHERE p.id = ? FOR UPDATE'
    );
    $st->execute([$idProduk]);
    $r = $st->fetch();
    if (!$r) {
        throw new AppError('Produk stok tidak ditemukan.');
    }
    $baru = (int)$r['jumlah'] + $perubahan;
    if ($baru < 0) {
        throw new AppError("Stok {$r['nama_produk']} tidak cukup (tersisa {$r['jumlah']}).");
    }
    if ($r['id_stok'] === null) {
        $pdo->prepare('INSERT INTO stok (id, id_produk, jumlah_saat_ini) VALUES (?,?,?)')
            ->execute([uuid(), $idProduk, $baru]);
    } else {
        $pdo->prepare('UPDATE stok SET jumlah_saat_ini = ? WHERE id = ?')->execute([$baru, $r['id_stok']]);
    }
    if ($perubahan !== 0) {
        $pdo->prepare(
            'INSERT INTO pergerakan_stok (id, id_produk, id_transaksi, perubahan, jenis_pergerakan, keterangan)
             VALUES (?,?,?,?,?,?)'
        )->execute([uuid(), $idProduk, $idTransaksi, $perubahan, $jenisPergerakan, $keterangan]);
    }
    return $baru;
}
