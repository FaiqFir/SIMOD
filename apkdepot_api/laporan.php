<?php
// =====================================================================
// laporan.php — Beranda, Laporan (harian / ringkasan / ekspor), Pengingat
// Aksi (?aksi=...):
//   beranda | harian | ringkasan | ekspor
//   pengingat_list | pengingat_ubah | pengingat_cek
// Semua angka uang hanya menghitung transaksi berstatus 'aktif' (spec §6.5).
// =====================================================================
require_once __DIR__ . '/koneksi.php';

/**
 * Total pemasukan/pengeluaran transaksi aktif pada rentang [$awal, $akhir] (tanggal inklusif).
 * Mengembalikan angka dalam format yang dibaca laporan_screen.dart.
 */
function totalRentang(string $idDepot, string $awal, string $akhir): array
{
    $st = db()->prepare(
        "SELECT COALESCE(SUM(CASE WHEN tipe_arus_kas = 'pemasukan'   THEN total ELSE 0 END), 0) AS masuk,
                COALESCE(SUM(CASE WHEN tipe_arus_kas = 'pengeluaran' THEN total ELSE 0 END), 0) AS keluar,
                COUNT(*) AS jumlah
         FROM transaksi
         WHERE id_depot = ? AND status = 'aktif'
           AND dibuat_pada >= ? AND dibuat_pada < DATE_ADD(?, INTERVAL 1 DAY)"
    );
    $st->execute([$idDepot, $awal . ' 00:00:00', $akhir]);
    $r = $st->fetch();
    $masuk = (float)$r['masuk'];
    $keluar = (float)$r['keluar'];
    return [
        'total_pemasukan' => $masuk,
        'total_pengeluaran' => $keluar,
        'selisih' => $masuk - $keluar,
        'jumlah_transaksi' => (int)$r['jumlah'],
    ];
}

/** Transaksi aktif pada rentang, lengkap dengan nama produk & peminjam */
function transaksiRentang(string $idDepot, string $awal, string $akhir, ?int $limit = null): array
{
    $sql = "SELECT t.id, t.jenis_aksi, t.id_produk, p.nama_produk, t.id_peminjam, m.nama AS nama_peminjam,
                   t.deskripsi, t.jumlah, t.harga_satuan, t.total, t.tipe_arus_kas, t.status,
                   t.dibatalkan_pada, t.alasan_batal, t.catatan, t.dibuat_pada
            FROM transaksi t
            LEFT JOIN produk p ON p.id = t.id_produk
            LEFT JOIN peminjam m ON m.id = t.id_peminjam
            WHERE t.id_depot = ? AND t.status = 'aktif'
              AND t.dibuat_pada >= ? AND t.dibuat_pada < DATE_ADD(?, INTERVAL 1 DAY)
            ORDER BY t.dibuat_pada DESC, t.id DESC";
    if ($limit !== null) {
        $sql .= ' LIMIT ' . (int)$limit;
    }
    $st = db()->prepare($sql);
    $st->execute([$idDepot, $awal . ' 00:00:00', $akhir]);
    $hasil = [];
    foreach ($st->fetchAll() as $r) {
        $r['jumlah'] = (int)$r['jumlah'];
        $r['harga_satuan'] = $r['harga_satuan'] !== null ? (float)$r['harga_satuan'] : null;
        $r['total'] = (float)$r['total'];
        if ($r['jenis_aksi'] === 'ganti_sparepart') {
            $r['deskripsi'] = null; // kolom ini dipakai internal untuk sparepart
        }
        $hasil[] = $r;
    }
    return $hasil;
}

/** Angka rupiah untuk CSV: bulat tanpa desimal, selain itu koma desimal (cocok Excel Indonesia) */
function angkaCsv(?float $n): string
{
    if ($n === null) {
        return '';
    }
    return floor($n) == $n ? (string)(int)$n : str_replace('.', ',', rtrim(rtrim(number_format($n, 2, '.', ''), '0'), '.'));
}

/** Cegah formula injection di Excel */
function amanCsv(?string $s): string
{
    $s = (string)$s;
    return ($s !== '' && strpos("=+-@\t\r", $s[0]) !== false) ? "'" . $s : $s;
}

$aksi = aksi();
$idDepot = depotAktif();
$pdo = db();

switch ($aksi) {

    // ==================================================================
    // BERANDA — kartu omset hari ini, ringkasan stok, pengingat
    // ==================================================================
    case 'beranda':
        $hariIni = date('Y-m-d');
        $tot = totalRentang($idDepot, $hariIni, $hariIni);

        $stok = $pdo->prepare(
            "SELECT p.jenis, COALESCE(SUM(s.jumlah_saat_ini), 0) AS jumlah
             FROM produk p LEFT JOIN stok s ON s.id_produk = p.id
             WHERE p.id_depot = ? AND p.aktif = 1 AND p.jenis IN ('galon_kosong','es')
             GROUP BY p.jenis"
        );
        $stok->execute([$idDepot]);
        $perJenis = ['galon_kosong' => 0, 'es' => 0];
        foreach ($stok->fetchAll() as $r) {
            $perJenis[$r['jenis']] = (int)$r['jumlah'];
        }

        $pinjam = $pdo->prepare('SELECT COALESCE(SUM(jumlah_galon_dipinjam), 0) FROM peminjam WHERE id_depot = ?');
        $pinjam->execute([$idDepot]);

        sukses([
            'pemasukan_hari_ini' => $tot['total_pemasukan'],
            'pengeluaran_hari_ini' => $tot['total_pengeluaran'],
            'stok_galon_kosong' => $perJenis['galon_kosong'],
            'stok_es' => $perJenis['es'],
            'galon_dipinjam' => (int)$pinjam->fetchColumn(),
            'pengingat' => daftarPengingatJson($idDepot, null, true),
        ]);
        break;

    // ==================================================================
    // HARIAN — GET tanggal (yyyy-MM-dd)
    // Grafik selalu berisi 24 titik (00:00 sampai 23:00), termasuk jam kosong.
    // ==================================================================
    case 'harian':
        $tgl = cekTanggal(input('tanggal', date('Y-m-d')));
        $hasil = totalRentang($idDepot, $tgl, $tgl);
        $hasil['tanggal'] = $tgl;
        $hasil['transaksi'] = transaksiRentang($idDepot, $tgl, $tgl);

        $grafikJam = $pdo->prepare(
            "SELECT HOUR(dibuat_pada) AS jam,
                    COALESCE(SUM(CASE WHEN tipe_arus_kas = 'pemasukan' THEN total ELSE 0 END), 0) AS pemasukan,
                    COALESCE(SUM(CASE WHEN tipe_arus_kas = 'pengeluaran' THEN total ELSE 0 END), 0) AS pengeluaran
             FROM transaksi
             WHERE id_depot = ? AND status = 'aktif'
               AND dibuat_pada >= ? AND dibuat_pada < DATE_ADD(?, INTERVAL 1 DAY)
             GROUP BY HOUR(dibuat_pada) ORDER BY jam"
        );
        $grafikJam->execute([$idDepot, $tgl . ' 00:00:00', $tgl]);
        $perJam = [];
        foreach ($grafikJam->fetchAll() as $baris) {
            $perJam[(int)$baris['jam']] = $baris;
        }

        $hasil['grafik_jam'] = [];
        for ($jam = 0; $jam < 24; $jam++) {
            $baris = $perJam[$jam] ?? null;
            $hasil['grafik_jam'][] = [
                'jam' => $jam,
                'label' => sprintf('%02d:00', $jam),
                'pemasukan' => $baris ? (float)$baris['pemasukan'] : 0,
                'pengeluaran' => $baris ? (float)$baris['pengeluaran'] : 0,
            ];
        }

        sukses($hasil);
        break;

    // ==================================================================
    // RINGKASAN — GET periode (minggu|bulan|tahun), tanggal
    //  minggu = Senin–Minggu yang memuat tanggal itu; bulan & tahun sesuai kalender
    //  grafik_harian = [{tanggal, pemasukan, pengeluaran}] per hari yang ada transaksinya
    // ==================================================================
    case 'ringkasan':
        $periode = (string)input('periode', 'bulan');
        $tgl = new DateTimeImmutable(cekTanggal(input('tanggal', date('Y-m-d'))));
        switch ($periode) {
            case 'minggu':
                $awal = $tgl->modify('monday this week');
                $akhir = $awal->modify('+6 days');
                break;
            case 'bulan':
                $awal = $tgl->modify('first day of this month');
                $akhir = $tgl->modify('last day of this month');
                break;
            case 'tahun':
                $awal = new DateTimeImmutable($tgl->format('Y') . '-01-01');
                $akhir = new DateTimeImmutable($tgl->format('Y') . '-12-31');
                break;
            default:
                throw new AppError('Periode harus minggu, bulan, atau tahun.');
        }
        $a = $awal->format('Y-m-d');
        $b = $akhir->format('Y-m-d');

        $hasil = totalRentang($idDepot, $a, $b);
        $hasil['periode'] = $periode;
        $hasil['dari'] = $a;
        $hasil['sampai'] = $b;

        $g = $pdo->prepare(
            "SELECT DATE(dibuat_pada) AS tanggal,
                    COALESCE(SUM(CASE WHEN tipe_arus_kas = 'pemasukan'   THEN total ELSE 0 END), 0) AS pemasukan,
                    COALESCE(SUM(CASE WHEN tipe_arus_kas = 'pengeluaran' THEN total ELSE 0 END), 0) AS pengeluaran
             FROM transaksi
             WHERE id_depot = ? AND status = 'aktif'
               AND dibuat_pada >= ? AND dibuat_pada < DATE_ADD(?, INTERVAL 1 DAY)
             GROUP BY DATE(dibuat_pada) ORDER BY tanggal"
        );
        $g->execute([$idDepot, $a . ' 00:00:00', $b]);
        $hasil['grafik_harian'] = array_map(function ($r) {
            return [
                'tanggal' => $r['tanggal'],
                'pemasukan' => (float)$r['pemasukan'],
                'pengeluaran' => (float)$r['pengeluaran'],
            ];
        }, $g->fetchAll());
        sukses($hasil);
        break;

    // ==================================================================
    // EKSPOR — GET dari, sampai -> unduhan CSV (dibuka di tab baru oleh Flutter)
    // Pemisah ';' + BOM UTF-8 agar langsung rapi di Excel versi Indonesia
    // ==================================================================
    case 'ekspor':
        $sampai = cekTanggal(input('sampai', date('Y-m-d')), 'Tanggal sampai');
        $dari = cekTanggal(input('dari', date('Y-m-01')), 'Tanggal dari');
        if ($dari > $sampai) {
            throw new AppError('Tanggal dari tidak boleh setelah tanggal sampai.');
        }
        $baris = transaksiRentang($idDepot, $dari, $sampai);
        $baris = array_reverse($baris); // kronologis: lama -> baru

        $label = [
            'isi_ulang' => 'Isi Ulang', 'beli_galon_kosong' => 'Beli Galon', 'galon_kosong_isi' => 'Beli Galon + Isi',
            'beli_es' => 'Beli Es', 'pinjam_galon_isi' => 'Pinjam Galon + Isi', 'catat_pengeluaran' => 'Pengeluaran',
            'pendapatan_lain' => 'Pendapatan Lainnya', 'ganti_sparepart' => 'Ganti Sparepart', 'kembalikan_galon' => 'Kembali Galon',
        ];

        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="laporan_' . $dari . '_sd_' . $sampai . '.csv"');
        $out = fopen('php://output', 'w');
        fwrite($out, "\xEF\xBB\xBF");
        fputcsv($out, ['Tanggal', 'Jenis Aksi', 'Nama Produk / Deskripsi', 'Jumlah', 'Harga Satuan', 'Total', 'Arus Kas'], ';');
        foreach ($baris as $r) {
            $nama = $r['nama_produk'] ?? $r['deskripsi'] ?? $r['nama_peminjam'] ?? '';
            fputcsv($out, [
                $r['dibuat_pada'],
                $label[$r['jenis_aksi']] ?? $r['jenis_aksi'],
                amanCsv($nama),
                $r['jumlah'],
                angkaCsv($r['harga_satuan']),
                angkaCsv($r['total']),
                $r['tipe_arus_kas'],
            ], ';');
        }
        $tot = totalRentang($idDepot, $dari, $sampai);
        fputcsv($out, [], ';');
        fputcsv($out, ['', '', 'Total pemasukan', '', '', angkaCsv($tot['total_pemasukan']), ''], ';');
        fputcsv($out, ['', '', 'Total pengeluaran', '', '', angkaCsv($tot['total_pengeluaran']), ''], ';');
        fputcsv($out, ['', '', 'Selisih', '', '', angkaCsv($tot['selisih']), ''], ';');
        fclose($out);
        exit;

    // ==================================================================
    // PENGINGAT
    // ==================================================================

    // GET [status] — kosong = semua
    case 'pengingat_list':
        sukses(daftarPengingatJson($idDepot, input('status')));
        break;

    // POST id, status (belum_dibaca | dibaca | selesai)
    case 'pengingat_ubah':
        $id = (string)wajib('id', 'ID pengingat');
        $status = (string)wajib('status', 'Status');
        if (!in_array($status, ['belum_dibaca', 'dibaca', 'selesai'], true)) {
            throw new AppError('Status pengingat tidak valid.');
        }
        $st = $pdo->prepare('UPDATE pengingat SET status = ? WHERE id = ? AND id_depot = ?');
        $st->execute([$status, $id, $idDepot]);
        $cek = $pdo->prepare('SELECT 1 FROM pengingat WHERE id = ? AND id_depot = ?');
        $cek->execute([$id, $idDepot]);
        if (!$cek->fetch()) {
            throw new AppError('Pengingat tidak ditemukan.');
        }
        sukses(null);
        break;

    // GET — periksa stok & sparepart sekarang
    case 'pengingat_cek':
        periksaPengingat($idDepot);
        sukses(null);
        break;

    default:
        throw new AppError('Aksi tidak dikenal: ' . $aksi);
}
