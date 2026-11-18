<?php
// =====================================================================
// transaksi.php — Pusat integrasi: 9 aksi transaksi, riwayat, detail, pembatalan
// Aksi (?aksi=...):
//   isi_ulang | beli_galon_kosong | galon_kosong_isi | beli_es | pinjam_galon_isi
//   catat_pengeluaran | pendapatan_lain | ganti_sparepart | kembalikan_galon
//   riwayat | detail | batalkan
// Setiap aksi mencatat transaksi + efek stok + efek peminjam dalam SATU
// transaksi database: kalau salah satu gagal, semuanya dibatalkan.
// =====================================================================
require_once __DIR__ . '/koneksi.php';

const BATAS_JUMLAH = 100000;

/** Satu transaksi + nama produk & peminjam, sesuai TransaksiModel.fromJson */
function transaksiJson(string $id): array
{
    $st = db()->prepare(
        'SELECT t.id, t.jenis_aksi, t.id_produk, p.nama_produk, t.id_peminjam, m.nama AS nama_peminjam,
                t.deskripsi, t.jumlah, t.harga_satuan, t.total, t.tipe_arus_kas, t.status,
                t.dibatalkan_pada, t.alasan_batal, t.catatan, t.dibuat_pada
         FROM transaksi t
         LEFT JOIN produk p ON p.id = t.id_produk
         LEFT JOIN peminjam m ON m.id = t.id_peminjam
         WHERE t.id = ?'
    );
    $st->execute([$id]);
    $r = $st->fetch();
    return $r ? rapikanTransaksi($r) : [];
}

function rapikanTransaksi(array $r): array
{
    $r['jumlah'] = (int)$r['jumlah'];
    $r['harga_satuan'] = $r['harga_satuan'] !== null ? (float)$r['harga_satuan'] : null;
    $r['total'] = (float)$r['total'];
    // Untuk ganti_sparepart, kolom deskripsi dipakai internal (tanggal ganti sebelumnya)
    if ($r['jenis_aksi'] === 'ganti_sparepart') {
        $r['deskripsi'] = null;
    }
    return $r;
}

/** Produk milik depot, aktif, dan harus berjenis tertentu */
function ambilProduk(string $idDepot, string $jenis, string $label): array
{
    $id = (string)wajib('id_produk', $label);
    $st = db()->prepare('SELECT * FROM produk WHERE id = ? AND id_depot = ? AND aktif = 1');
    $st->execute([$id, $idDepot]);
    $p = $st->fetch();
    if (!$p) {
        throw new AppError("$label tidak ditemukan.");
    }
    if ($p['jenis'] !== $jenis) {
        throw new AppError("Produk yang dipilih bukan $label.");
    }
    return $p;
}

/** Produk "Galon Kosong" yang menyimpan stok galon depot (yang aktif tertua) */
function produkGalonKosong(string $idDepot): string
{
    $st = db()->prepare(
        "SELECT id FROM produk WHERE id_depot = ? AND jenis = 'galon_kosong' AND aktif = 1
         ORDER BY dibuat_pada, id LIMIT 1"
    );
    $st->execute([$idDepot]);
    $id = $st->fetchColumn();
    if (!$id) {
        throw new AppError('Belum ada produk "Galon Kosong". Tambahkan dulu di menu Produk agar stok galon bisa dilacak.');
    }
    return $id;
}

/** Peminjam existing milik depot, dikunci untuk diubah */
function kunciPeminjam(string $idDepot, string $id): array
{
    $st = db()->prepare('SELECT * FROM peminjam WHERE id = ? AND id_depot = ? FOR UPDATE');
    $st->execute([$id, $idDepot]);
    $m = $st->fetch();
    if (!$m) {
        throw new AppError('Peminjam tidak ditemukan.');
    }
    return $m;
}

/** Sisipkan baris transaksi, kembalikan id-nya */
function simpanTransaksi(string $idDepot, string $jenisAksi, array $f): string
{
    $id = uuid();
    db()->prepare(
        'INSERT INTO transaksi (id, id_depot, jenis_aksi, id_produk, id_peminjam, deskripsi, jumlah,
                                harga_satuan, total, tipe_arus_kas, catatan)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)'
    )->execute([
        $id, $idDepot, $jenisAksi,
        $f['id_produk'] ?? null, $f['id_peminjam'] ?? null, $f['deskripsi'] ?? null,
        $f['jumlah'] ?? 1, $f['harga_satuan'] ?? null, $f['total'] ?? 0,
        $f['tipe_arus_kas'], $f['catatan'] ?? null,
    ]);
    return $id;
}

/** Jalankan $isi di dalam transaksi database; hasilnya id transaksi baru */
function jalankan(string $idDepot, callable $isi): void
{
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $idTransaksi = $isi($pdo);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
    periksaPengingat($idDepot);
    sukses(transaksiJson($idTransaksi));
}

$aksi = aksi();
$idDepot = depotAktif();
$pdo = db();

switch ($aksi) {

    // ==================================================================
    // 1. ISI ULANG — id_produk (jenis_air), jumlah | stok tidak berubah | pemasukan
    // ==================================================================
    case 'isi_ulang':
        $p = ambilProduk($idDepot, 'jenis_air', 'Jenis air');
        $jumlah = inputInt('jumlah', 'Jumlah', 1);
        if ($jumlah > BATAS_JUMLAH) throw new AppError('Jumlah terlalu besar.');
        jalankan($idDepot, function () use ($idDepot, $p, $jumlah) {
            return simpanTransaksi($idDepot, 'isi_ulang', [
                'id_produk' => $p['id'], 'jumlah' => $jumlah, 'harga_satuan' => $p['harga'],
                'total' => $p['harga'] * $jumlah, 'tipe_arus_kas' => 'pemasukan', 'catatan' => input('catatan'),
            ]);
        });
        break;

    // ==================================================================
    // 2. BELI GALON — id_produk (galon_kosong), jumlah | stok galon kosong −jumlah | pemasukan
    // ==================================================================
    case 'beli_galon_kosong':
        $p = ambilProduk($idDepot, 'galon_kosong', 'Galon kosong');
        $jumlah = inputInt('jumlah', 'Jumlah', 1);
        if ($jumlah > BATAS_JUMLAH) throw new AppError('Jumlah terlalu besar.');
        jalankan($idDepot, function () use ($idDepot, $p, $jumlah) {
            $id = simpanTransaksi($idDepot, 'beli_galon_kosong', [
                'id_produk' => $p['id'], 'jumlah' => $jumlah, 'harga_satuan' => $p['harga'],
                'total' => $p['harga'] * $jumlah, 'tipe_arus_kas' => 'pemasukan', 'catatan' => input('catatan'),
            ]);
            ubahStok($p['id'], -$jumlah, $id, 'otomatis', 'Beli galon');
            return $id;
        });
        break;

    // ==================================================================
    // 3. BELI GALON + ISI — id_produk (galon_kosong_isi), jumlah
    //    stok galon kosong −jumlah (produk Galon Kosong utama depot) | pemasukan
    // ==================================================================
    case 'galon_kosong_isi':
        $p = ambilProduk($idDepot, 'galon_kosong_isi', 'Galon kosong + isi');
        $jumlah = inputInt('jumlah', 'Jumlah', 1);
        if ($jumlah > BATAS_JUMLAH) throw new AppError('Jumlah terlalu besar.');
        jalankan($idDepot, function () use ($idDepot, $p, $jumlah) {
            $idGalon = produkGalonKosong($idDepot);
            $id = simpanTransaksi($idDepot, 'galon_kosong_isi', [
                'id_produk' => $p['id'], 'jumlah' => $jumlah, 'harga_satuan' => $p['harga'],
                'total' => $p['harga'] * $jumlah, 'tipe_arus_kas' => 'pemasukan', 'catatan' => input('catatan'),
            ]);
            ubahStok($idGalon, -$jumlah, $id, 'otomatis', 'Beli galon + isi');
            return $id;
        });
        break;

    // ==================================================================
    // 4. BELI ES — id_produk (es), jumlah | stok es −jumlah | pemasukan
    // ==================================================================
    case 'beli_es':
        $p = ambilProduk($idDepot, 'es', 'Jenis es');
        $jumlah = inputInt('jumlah', 'Jumlah', 1);
        if ($jumlah > BATAS_JUMLAH) throw new AppError('Jumlah terlalu besar.');
        jalankan($idDepot, function () use ($idDepot, $p, $jumlah) {
            $id = simpanTransaksi($idDepot, 'beli_es', [
                'id_produk' => $p['id'], 'jumlah' => $jumlah, 'harga_satuan' => $p['harga'],
                'total' => $p['harga'] * $jumlah, 'tipe_arus_kas' => 'pemasukan', 'catatan' => input('catatan'),
            ]);
            ubahStok($p['id'], -$jumlah, $id, 'otomatis', 'Beli es');
            return $id;
        });
        break;

    // ==================================================================
    // 5. PINJAM GALON + ISI — id_produk (jenis_air), jumlah,
    //    id_peminjam ATAU nama+alamat (find-or-create, spec §6.2)
    //    stok galon kosong −jumlah, galon dipinjam +jumlah | pemasukan
    // ==================================================================
    case 'pinjam_galon_isi':
        $p = ambilProduk($idDepot, 'jenis_air', 'Jenis air');
        $jumlah = inputInt('jumlah', 'Jumlah', 1);
        if ($jumlah > BATAS_JUMLAH) throw new AppError('Jumlah terlalu besar.');
        $idPeminjamIn = input('id_peminjam');
        $namaBaru = input('nama');
        $alamatBaru = input('alamat');
        if ($idPeminjamIn === null && ($namaBaru === null || $alamatBaru === null)) {
            throw new AppError('Pilih peminjam, atau isi nama dan alamat peminjam baru.');
        }
        jalankan($idDepot, function () use ($idDepot, $p, $jumlah, $idPeminjamIn, $namaBaru, $alamatBaru) {
            $pdo = db();
            if ($idPeminjamIn !== null) {
                $m = kunciPeminjam($idDepot, (string)$idPeminjamIn);
                $idPeminjam = $m['id'];
            } else {
                if (mb_strlen((string)$namaBaru) > 100) throw new AppError('Nama peminjam maksimal 100 karakter.');
                $idPeminjam = uuid();
                $pdo->prepare('INSERT INTO peminjam (id, id_depot, nama, alamat, jumlah_galon_dipinjam) VALUES (?,?,?,?,0)')
                    ->execute([$idPeminjam, $idDepot, $namaBaru, $alamatBaru]);
            }
            $idGalon = produkGalonKosong($idDepot);
            $id = simpanTransaksi($idDepot, 'pinjam_galon_isi', [
                'id_produk' => $p['id'], 'id_peminjam' => $idPeminjam, 'jumlah' => $jumlah,
                'harga_satuan' => $p['harga'], 'total' => $p['harga'] * $jumlah,
                'tipe_arus_kas' => 'pemasukan', 'catatan' => input('catatan'),
            ]);
            ubahStok($idGalon, -$jumlah, $id, 'otomatis', 'Pinjam galon + isi');
            $pdo->prepare('UPDATE peminjam SET jumlah_galon_dipinjam = jumlah_galon_dipinjam + ? WHERE id = ?')
                ->execute([$jumlah, $idPeminjam]);
            return $id;
        });
        break;

    // ==================================================================
    // 6 & 7. PENGELUARAN / PENDAPATAN LAINNYA — deskripsi, nominal, catatan
    // ==================================================================
    case 'catat_pengeluaran':
    case 'pendapatan_lain':
        $deskripsi = (string)wajib('deskripsi', 'Deskripsi');
        if (mb_strlen($deskripsi) > 255) throw new AppError('Deskripsi maksimal 255 karakter.');
        $nominal = inputUang('nominal', 'Nominal');
        $arus = $aksi === 'catat_pengeluaran' ? 'pengeluaran' : 'pemasukan';
        jalankan($idDepot, function () use ($idDepot, $aksi, $deskripsi, $nominal, $arus) {
            return simpanTransaksi($idDepot, $aksi, [
                'deskripsi' => $deskripsi, 'jumlah' => 1, 'harga_satuan' => $nominal,
                'total' => $nominal, 'tipe_arus_kas' => $arus, 'catatan' => input('catatan'),
            ]);
        });
        break;

    // ==================================================================
    // 8. GANTI SPAREPART — id_produk (sparepart), biaya (opsional)
    //    terakhir_diganti -> hari ini | pengeluaran bila ada biaya
    //    (tanggal lama disimpan di kolom deskripsi agar bisa dipulihkan saat dibatalkan)
    // ==================================================================
    case 'ganti_sparepart':
        $p = ambilProduk($idDepot, 'sparepart', 'Sparepart');
        $biaya = input('biaya') === null ? 0.0 : inputUang('biaya', 'Biaya', false);
        jalankan($idDepot, function () use ($idDepot, $p, $biaya) {
            $id = simpanTransaksi($idDepot, 'ganti_sparepart', [
                'id_produk' => $p['id'], 'jumlah' => 1,
                'harga_satuan' => $biaya > 0 ? $biaya : null, 'total' => $biaya,
                'tipe_arus_kas' => 'pengeluaran', 'catatan' => input('catatan'),
                'deskripsi' => 'sebelumnya:' . ($p['terakhir_diganti'] ?? '-'),
            ]);
            db()->prepare('UPDATE produk SET terakhir_diganti = CURDATE() WHERE id = ?')->execute([$p['id']]);
            return $id;
        });
        break;

    // ==================================================================
    // 9. KEMBALI GALON — id_peminjam (wajib sudah ada), jumlah ≤ yang dipinjam
    //    galon dipinjam −jumlah, stok galon kosong +jumlah | tanpa efek uang
    // ==================================================================
    case 'kembalikan_galon':
        $idPeminjamIn = (string)wajib('id_peminjam', 'Peminjam');
        $jumlah = inputInt('jumlah', 'Jumlah', 1);
        jalankan($idDepot, function () use ($idDepot, $idPeminjamIn, $jumlah) {
            $m = kunciPeminjam($idDepot, $idPeminjamIn);
            if ($jumlah > (int)$m['jumlah_galon_dipinjam']) {
                throw new AppError("Jumlah melebihi galon yang dipinjam {$m['nama']} (sisa {$m['jumlah_galon_dipinjam']}).");
            }
            $idGalon = produkGalonKosong($idDepot);
            $id = simpanTransaksi($idDepot, 'kembalikan_galon', [
                'id_peminjam' => $m['id'], 'jumlah' => $jumlah, 'total' => 0,
                'tipe_arus_kas' => 'pemasukan', 'catatan' => input('catatan'),
            ]);
            ubahStok($idGalon, $jumlah, $id, 'otomatis', 'Galon dikembalikan');
            db()->prepare('UPDATE peminjam SET jumlah_galon_dipinjam = jumlah_galon_dipinjam - ? WHERE id = ?')
                ->execute([$jumlah, $m['id']]);
            return $id;
        });
        break;

    // ==================================================================
    // RIWAYAT — GET [dari], [sampai], [jenis_aksi], [limit]
    // Menyertakan transaksi yang dibatalkan (ditandai status = dibatalkan)
    // ==================================================================
    case 'riwayat':
        $sql = 'SELECT t.id, t.jenis_aksi, t.id_produk, p.nama_produk, t.id_peminjam, m.nama AS nama_peminjam,
                       t.deskripsi, t.jumlah, t.harga_satuan, t.total, t.tipe_arus_kas, t.status,
                       t.dibatalkan_pada, t.alasan_batal, t.catatan, t.dibuat_pada
                FROM transaksi t
                LEFT JOIN produk p ON p.id = t.id_produk
                LEFT JOIN peminjam m ON m.id = t.id_peminjam
                WHERE t.id_depot = ?';
        $par = [$idDepot];
        if (($dari = input('dari')) !== null) {
            $sql .= ' AND t.dibuat_pada >= ?';
            $par[] = cekTanggal($dari, 'Tanggal dari') . ' 00:00:00';
        }
        if (($sampai = input('sampai')) !== null) {
            $sql .= ' AND t.dibuat_pada < DATE_ADD(?, INTERVAL 1 DAY)';
            $par[] = cekTanggal($sampai, 'Tanggal sampai');
        }
        if (($jenis = input('jenis_aksi')) !== null) {
            $sql .= ' AND t.jenis_aksi = ?';
            $par[] = $jenis;
        }
        $limit = max(1, min(1000, (int)input('limit', 300)));
        $sql .= ' ORDER BY t.dibuat_pada DESC, t.id DESC LIMIT ' . $limit;
        $st = $pdo->prepare($sql);
        $st->execute($par);
        sukses(array_map('rapikanTransaksi', $st->fetchAll()));
        break;

    // GET id
    case 'detail':
        $id = (string)wajib('id', 'ID transaksi');
        $t = transaksiJson($id);
        $cek = $pdo->prepare('SELECT 1 FROM transaksi WHERE id = ? AND id_depot = ?');
        $cek->execute([$id, $idDepot]);
        if (!$t || !$cek->fetch()) {
            throw new AppError('Transaksi tidak ditemukan.');
        }
        sukses($t);
        break;

    // ==================================================================
    // BATALKAN — POST id, alasan (spec §6.3)
    // Baris tidak dihapus: ditandai dibatalkan, efek stok & peminjam dibalik.
    // Ditolak bila pembalikan membuat stok / pinjaman menjadi minus.
    // ==================================================================
    case 'batalkan':
        $id = (string)wajib('id', 'ID transaksi');
        $alasan = (string)input('alasan', 'Dibatalkan oleh pengguna');

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare('SELECT * FROM transaksi WHERE id = ? AND id_depot = ? FOR UPDATE');
            $st->execute([$id, $idDepot]);
            $t = $st->fetch();
            if (!$t) {
                throw new AppError('Transaksi tidak ditemukan.');
            }
            if ($t['status'] === 'dibatalkan') {
                throw new AppError('Transaksi ini sudah dibatalkan.');
            }

            // 1) Balik semua pergerakan stok yang dibuat transaksi ini
            $pg = $pdo->prepare("SELECT id_produk, perubahan FROM pergerakan_stok WHERE id_transaksi = ? AND jenis_pergerakan = 'otomatis'");
            $pg->execute([$id]);
            foreach ($pg->fetchAll() as $g) {
                ubahStok($g['id_produk'], -(int)$g['perubahan'], $id, 'otomatis', 'Pembatalan transaksi');
            }

            // 2) Balik jumlah galon dipinjam
            if ($t['jenis_aksi'] === 'pinjam_galon_isi' || $t['jenis_aksi'] === 'kembalikan_galon') {
                $m = kunciPeminjam($idDepot, (string)$t['id_peminjam']);
                $selisih = $t['jenis_aksi'] === 'pinjam_galon_isi' ? -(int)$t['jumlah'] : (int)$t['jumlah'];
                if ((int)$m['jumlah_galon_dipinjam'] + $selisih < 0) {
                    throw new AppError("Tidak bisa dibatalkan: {$m['nama']} sudah mengembalikan galon dari peminjaman ini. Batalkan transaksi \"Kembali Galon\" terlebih dahulu.");
                }
                $pdo->prepare('UPDATE peminjam SET jumlah_galon_dipinjam = jumlah_galon_dipinjam + ? WHERE id = ?')
                    ->execute([$selisih, $m['id']]);
            }

            // 3) Pulihkan tanggal terakhir diganti (hanya bila belum ada penggantian aktif yang lebih baru)
            if ($t['jenis_aksi'] === 'ganti_sparepart' && $t['id_produk'] !== null) {
                $lebihBaru = $pdo->prepare(
                    "SELECT 1 FROM transaksi WHERE id_produk = ? AND jenis_aksi = 'ganti_sparepart'
                     AND status = 'aktif' AND id <> ? AND dibuat_pada > ? LIMIT 1"
                );
                $lebihBaru->execute([$t['id_produk'], $id, $t['dibuat_pada']]);
                if (!$lebihBaru->fetch() && preg_match('/^sebelumnya:(\d{4}-\d{2}-\d{2})$/', (string)$t['deskripsi'], $mm)) {
                    $pdo->prepare('UPDATE produk SET terakhir_diganti = ? WHERE id = ?')->execute([$mm[1], $t['id_produk']]);
                }
            }

            // 4) Tandai batal (laporan hanya menghitung yang 'aktif')
            $pdo->prepare("UPDATE transaksi SET status = 'dibatalkan', dibatalkan_pada = NOW(), alasan_batal = ? WHERE id = ?")
                ->execute([$alasan, $id]);
            $pdo->commit();
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e;
        }
        periksaPengingat($idDepot);
        sukses(transaksiJson($id));
        break;

    default:
        throw new AppError('Aksi tidak dikenal: ' . $aksi);
}
