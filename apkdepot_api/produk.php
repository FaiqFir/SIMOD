<?php
// =====================================================================
// produk.php — Produk, Stok, dan Peminjam
// Aksi (?aksi=...):
//   produk_list | produk_tambah | produk_ubah | produk_nonaktif
//   stok_list | stok_riwayat | stok_koreksi
//   peminjam_list | peminjam_tambah | peminjam_ubah
// =====================================================================
require_once __DIR__ . '/koneksi.php';

const JENIS_PRODUK = ['jenis_air', 'galon_kosong', 'galon_kosong_isi', 'es', 'sparepart'];
const AMBANG_BAWAAN = 5;

/** Satu produk dalam bentuk yang dibaca ProdukModel.fromJson */
function produkJson(string $idProduk): array
{
    $st = db()->prepare(
        'SELECT id, nama_produk, jenis, harga, masa_pakai_hari, terakhir_diganti, ambang_stok_minimum, aktif
         FROM produk WHERE id = ?'
    );
    $st->execute([$idProduk]);
    return rapikanProduk($st->fetch());
}

function rapikanProduk(array $p): array
{
    $p['harga'] = $p['harga'] !== null ? (float)$p['harga'] : null;
    $p['masa_pakai_hari'] = $p['masa_pakai_hari'] !== null ? (int)$p['masa_pakai_hari'] : null;
    $p['ambang_stok_minimum'] = $p['ambang_stok_minimum'] !== null ? (int)$p['ambang_stok_minimum'] : null;
    $p['aktif'] = (int)$p['aktif'];
    return $p;
}

/** Ambil produk milik depot (aktif), atau tolak */
function produkMilikDepot(string $idProduk, string $idDepot, bool $harusAktif = true): array
{
    $st = db()->prepare('SELECT * FROM produk WHERE id = ? AND id_depot = ?');
    $st->execute([$idProduk, $idDepot]);
    $p = $st->fetch();
    if (!$p || ($harusAktif && !(int)$p['aktif'])) {
        throw new AppError('Produk tidak ditemukan.');
    }
    return $p;
}

/** Validasi field produk sesuai jenisnya (spec §6.1). Mengembalikan kolom siap simpan. */
function validasiProduk(string $jenis): array
{
    $nama = wajib('nama_produk', 'Nama produk');
    if (mb_strlen($nama) > 100) {
        throw new AppError('Nama produk maksimal 100 karakter.');
    }
    $d = [
        'nama_produk' => $nama,
        'harga' => null,
        'masa_pakai_hari' => null,
        'terakhir_diganti' => null,
        'ambang_stok_minimum' => null,
    ];
    if ($jenis === 'sparepart') {
        $d['masa_pakai_hari'] = inputInt('masa_pakai_hari', 'Masa pakai (hari)', 1);
        $d['terakhir_diganti'] = cekTanggal(input('terakhir_diganti'), 'Tanggal terakhir diganti');
    } else {
        $d['harga'] = inputUang('harga', 'Harga');
        if ($jenis === 'galon_kosong' || $jenis === 'es') {
            $d['ambang_stok_minimum'] = input('ambang_stok_minimum') === null
                ? AMBANG_BAWAAN
                : inputInt('ambang_stok_minimum', 'Ambang stok minimum', 0);
        }
    }
    return $d;
}

/** Nama produk harus unik per depot per jenis (pengecualian: baris dirinya sendiri) */
function cekNamaUnik(string $idDepot, string $jenis, string $nama, ?string $kecuali = null): ?array
{
    $st = db()->prepare('SELECT id, aktif FROM produk WHERE id_depot = ? AND jenis = ? AND nama_produk = ?');
    $st->execute([$idDepot, $jenis, $nama]);
    foreach ($st->fetchAll() as $r) {
        if ($r['id'] !== $kecuali) {
            return $r;
        }
    }
    return null;
}

/** Baris peminjam dalam bentuk PeminjamModel.fromJson */
function peminjamJson(string $id): array
{
    $st = db()->prepare('SELECT id, nama, alamat, jumlah_galon_dipinjam FROM peminjam WHERE id = ?');
    $st->execute([$id]);
    $p = $st->fetch();
    $p['jumlah_galon_dipinjam'] = (int)$p['jumlah_galon_dipinjam'];
    return $p;
}

/** Satu baris stok dalam bentuk StokModel.fromJson */
function stokJson(string $idProduk): array
{
    $st = db()->prepare(
        'SELECT p.id AS id_produk, p.nama_produk, p.jenis, COALESCE(s.jumlah_saat_ini, 0) AS jumlah_saat_ini,
                p.ambang_stok_minimum
         FROM produk p LEFT JOIN stok s ON s.id_produk = p.id WHERE p.id = ?'
    );
    $st->execute([$idProduk]);
    $r = $st->fetch();
    $r['jumlah_saat_ini'] = (int)$r['jumlah_saat_ini'];
    $r['ambang_stok_minimum'] = $r['ambang_stok_minimum'] !== null ? (int)$r['ambang_stok_minimum'] : null;
    return $r;
}

$aksi = aksi();
$idDepot = depotAktif();
$pdo = db();

switch ($aksi) {

    // ==================================================================
    // PRODUK
    // ==================================================================

    // GET id_depot, [jenis]  -> daftar produk aktif
    case 'produk_list':
        $sql = 'SELECT id, nama_produk, jenis, harga, masa_pakai_hari, terakhir_diganti, ambang_stok_minimum, aktif
                FROM produk WHERE id_depot = ? AND aktif = 1';
        $par = [$idDepot];
        $jenis = input('jenis');
        if ($jenis !== null) {
            if (!in_array($jenis, JENIS_PRODUK, true)) {
                throw new AppError('Jenis produk tidak valid.');
            }
            $sql .= ' AND jenis = ?';
            $par[] = $jenis;
        }
        $sql .= ' ORDER BY FIELD(jenis,"jenis_air","galon_kosong","galon_kosong_isi","es","sparepart"), nama_produk';
        $st = $pdo->prepare($sql);
        $st->execute($par);
        sukses(array_map('rapikanProduk', $st->fetchAll()));
        break;

    // POST nama_produk, jenis, harga | masa_pakai_hari+terakhir_diganti, ambang_stok_minimum, stok_awal
    case 'produk_tambah':
        $jenis = (string)wajib('jenis', 'Jenis produk');
        if (!in_array($jenis, JENIS_PRODUK, true)) {
            throw new AppError('Jenis produk tidak valid.');
        }
        $d = validasiProduk($jenis);
        $stokAwal = 0;
        if ($jenis === 'galon_kosong' || $jenis === 'es') {
            $stokAwal = input('stok_awal') === null ? 0 : inputInt('stok_awal', 'Stok awal', 0);
        }

        $pdo->beginTransaction();
        try {
            $ada = cekNamaUnik($idDepot, $jenis, $d['nama_produk']);
            if ($ada && (int)$ada['aktif'] === 1) {
                throw new AppError('Produk "' . $d['nama_produk'] . '" sudah ada untuk jenis ini.');
            }

            if ($ada) {
                // Nama sama pernah dihapus (nonaktif) -> hidupkan lagi, riwayatnya tetap utuh
                $idProduk = $ada['id'];
                $pdo->prepare(
                    'UPDATE produk SET harga = ?, masa_pakai_hari = ?, terakhir_diganti = ?,
                                       ambang_stok_minimum = ?, aktif = 1 WHERE id = ?'
                )->execute([$d['harga'], $d['masa_pakai_hari'], $d['terakhir_diganti'], $d['ambang_stok_minimum'], $idProduk]);
            } else {
                $idProduk = uuid();
                $pdo->prepare(
                    'INSERT INTO produk (id, id_depot, nama_produk, jenis, harga, masa_pakai_hari, terakhir_diganti, ambang_stok_minimum)
                     VALUES (?,?,?,?,?,?,?,?)'
                )->execute([$idProduk, $idDepot, $d['nama_produk'], $jenis, $d['harga'],
                    $d['masa_pakai_hari'], $d['terakhir_diganti'], $d['ambang_stok_minimum']]);
            }

            // Produk berstok: pastikan baris stok ada; stok awal dicatat sebagai pergerakan
            if ($jenis === 'galon_kosong' || $jenis === 'es') {
                ubahStok($idProduk, $stokAwal, null, 'koreksi_manual', 'Stok awal');
            }
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
        periksaPengingat($idDepot);
        sukses(produkJson($idProduk));
        break;

    // POST id, + field seperti tambah (jenis produk tidak bisa diganti)
    case 'produk_ubah':
        $p = produkMilikDepot((string)wajib('id', 'ID produk'), $idDepot);
        $d = validasiProduk($p['jenis']);
        if (cekNamaUnik($idDepot, $p['jenis'], $d['nama_produk'], $p['id'])) {
            throw new AppError('Produk "' . $d['nama_produk'] . '" sudah ada untuk jenis ini.');
        }
        $pdo->prepare(
            'UPDATE produk SET nama_produk = ?, harga = ?, masa_pakai_hari = ?, terakhir_diganti = ?,
                               ambang_stok_minimum = ? WHERE id = ?'
        )->execute([$d['nama_produk'], $d['harga'], $d['masa_pakai_hari'], $d['terakhir_diganti'],
            $d['ambang_stok_minimum'], $p['id']]);
        periksaPengingat($idDepot);
        sukses(produkJson($p['id']));
        break;

    // POST id  -> hapus lunak (aktif = 0); riwayat transaksi tetap
    case 'produk_nonaktif':
        $p = produkMilikDepot((string)wajib('id', 'ID produk'), $idDepot);
        $pdo->prepare('UPDATE produk SET aktif = 0 WHERE id = ?')->execute([$p['id']]);
        $pdo->prepare("UPDATE pengingat SET status = 'selesai' WHERE id_produk = ? AND status <> 'selesai'")
            ->execute([$p['id']]);
        sukses(null);
        break;

    // ==================================================================
    // STOK
    // ==================================================================

    // GET -> stok produk berstok (galon kosong & es) yang aktif
    case 'stok_list':
        $st = $pdo->prepare(
            "SELECT p.id AS id_produk, p.nama_produk, p.jenis, COALESCE(s.jumlah_saat_ini, 0) AS jumlah_saat_ini,
                    p.ambang_stok_minimum
             FROM produk p LEFT JOIN stok s ON s.id_produk = p.id
             WHERE p.id_depot = ? AND p.aktif = 1 AND p.jenis IN ('galon_kosong','es')
             ORDER BY p.jenis, p.nama_produk"
        );
        $st->execute([$idDepot]);
        $hasil = [];
        foreach ($st->fetchAll() as $r) {
            $r['jumlah_saat_ini'] = (int)$r['jumlah_saat_ini'];
            $r['ambang_stok_minimum'] = $r['ambang_stok_minimum'] !== null ? (int)$r['ambang_stok_minimum'] : null;
            $hasil[] = $r;
        }
        sukses($hasil);
        break;

    // GET id_produk -> 100 pergerakan terakhir
    case 'stok_riwayat':
        $p = produkMilikDepot((string)wajib('id_produk', 'ID produk'), $idDepot, false);
        $st = $pdo->prepare(
            'SELECT id, id_produk, id_transaksi, perubahan, jenis_pergerakan, keterangan, dibuat_pada
             FROM pergerakan_stok WHERE id_produk = ? ORDER BY dibuat_pada DESC, id DESC LIMIT 100'
        );
        $st->execute([$p['id']]);
        $hasil = [];
        foreach ($st->fetchAll() as $r) {
            $r['perubahan'] = (int)$r['perubahan'];
            $hasil[] = $r;
        }
        sukses($hasil);
        break;

    // POST id_produk, jumlah_baru, alasan -> selisih dihitung di sini
    case 'stok_koreksi':
        $p = produkMilikDepot((string)wajib('id_produk', 'ID produk'), $idDepot);
        if (!in_array($p['jenis'], ['galon_kosong', 'es'], true)) {
            throw new AppError('Hanya stok galon kosong dan es yang bisa dikoreksi.');
        }
        $jumlahBaru = inputInt('jumlah_baru', 'Jumlah stok baru', 0);
        $alasan = (string)input('alasan', 'Koreksi manual');

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare('SELECT COALESCE(jumlah_saat_ini, 0) FROM stok WHERE id_produk = ? FOR UPDATE');
            $st->execute([$p['id']]);
            $sekarang = (int)($st->fetchColumn() ?: 0);
            ubahStok($p['id'], $jumlahBaru - $sekarang, null, 'koreksi_manual', $alasan);
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
        periksaPengingat($idDepot);
        sukses(stokJson($p['id']));
        break;

    // ==================================================================
    // PEMINJAM
    // ==================================================================

    // GET [cari] -> cari berdasarkan nama atau alamat
    case 'peminjam_list':
        $sql = 'SELECT id, nama, alamat, jumlah_galon_dipinjam FROM peminjam WHERE id_depot = ?';
        $par = [$idDepot];
        $cari = input('cari');
        if ($cari !== null) {
            $like = '%' . addcslashes((string)$cari, '%_\\') . '%';
            $sql .= ' AND (nama LIKE ? OR alamat LIKE ?)';
            array_push($par, $like, $like);
        }
        $sql .= ' ORDER BY (jumlah_galon_dipinjam > 0) DESC, nama';
        $st = $pdo->prepare($sql);
        $st->execute($par);
        $hasil = [];
        foreach ($st->fetchAll() as $r) {
            $r['jumlah_galon_dipinjam'] = (int)$r['jumlah_galon_dipinjam'];
            $hasil[] = $r;
        }
        sukses($hasil);
        break;

    // POST nama, alamat
    case 'peminjam_tambah':
        $nama = wajib('nama', 'Nama peminjam');
        $alamat = wajib('alamat', 'Alamat peminjam');
        if (mb_strlen($nama) > 100) {
            throw new AppError('Nama peminjam maksimal 100 karakter.');
        }
        $id = uuid();
        $pdo->prepare('INSERT INTO peminjam (id, id_depot, nama, alamat) VALUES (?,?,?,?)')
            ->execute([$id, $idDepot, $nama, $alamat]);
        sukses(peminjamJson($id));
        break;

    // POST id, nama, alamat, jumlah_galon_dipinjam (koreksi manual dari halaman Produk)
    case 'peminjam_ubah':
        $id = (string)wajib('id', 'ID peminjam');
        $st = $pdo->prepare('SELECT id FROM peminjam WHERE id = ? AND id_depot = ?');
        $st->execute([$id, $idDepot]);
        if (!$st->fetch()) {
            throw new AppError('Peminjam tidak ditemukan.');
        }
        $nama = wajib('nama', 'Nama peminjam');
        $alamat = wajib('alamat', 'Alamat peminjam');
        $jumlah = input('jumlah_galon_dipinjam') === null ? 0 : inputInt('jumlah_galon_dipinjam', 'Jumlah galon dipinjam', 0);
        $pdo->prepare('UPDATE peminjam SET nama = ?, alamat = ?, jumlah_galon_dipinjam = ? WHERE id = ?')
            ->execute([$nama, $alamat, $jumlah, $id]);
        sukses(peminjamJson($id));
        break;

    default:
        throw new AppError('Aksi tidak dikenal: ' . $aksi);
}
