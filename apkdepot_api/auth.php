<?php
// auth.php — login, registrasi, ubah profil depot
// Aksi: masuk | daftar | depot_ubah | depot_get
require_once __DIR__ . '/koneksi.php';

$aksi = aksi();

switch ($aksi) {

    // POST nama_pengguna, kata_sandi
    // -> { pengguna:{id,nama_pengguna,nama_pengelola}, depot:{...} }
    case 'masuk':
        $nama = wajib('nama_pengguna', 'Nama pengguna');
        $sandi = (string)($_POST['kata_sandi'] ?? '');
        if ($sandi === '') {
            throw new AppError('Kata sandi wajib diisi.');
        }

        $st = db()->prepare('SELECT id, nama_pengguna, kata_sandi_hash, nama_pengelola FROM pengguna WHERE nama_pengguna = ?');
        $st->execute([$nama]);
        $u = $st->fetch();
        // Pesan sengaja sama agar tidak membocorkan apakah nama pengguna ada
        if (!$u || !password_verify($sandi, $u['kata_sandi_hash'])) {
            throw new AppError('Nama pengguna atau kata sandi salah.');
        }

        $d = db()->prepare('SELECT id FROM depot WHERE id_pengguna = ?');
        $d->execute([$u['id']]);
        $idDepot = $d->fetchColumn();
        if (!$idDepot) {
            throw new AppError('Akun ini belum memiliki data depot.');
        }

        sukses([
            'pengguna' => [
                'id' => $u['id'],
                'nama_pengguna' => $u['nama_pengguna'],
                'nama_pengelola' => $u['nama_pengelola'],
            ],
            'depot' => depotJson($idDepot),
        ]);
        break;

    // POST nama_pengguna, kata_sandi, nama_pengelola,
    //      nama_depot, alamat, jam_buka, jam_tutup
    // 1 akun = 1 depot; hasil sama seperti 'masuk' (langsung login).
    case 'daftar':
        $namaPengguna = wajib('nama_pengguna', 'Nama pengguna');
        $sandi = (string)($_POST['kata_sandi'] ?? '');
        $namaPengelola = wajib('nama_pengelola', 'Nama pengelola');
        $namaDepot = wajib('nama_depot', 'Nama depot');
        $alamat = wajib('alamat', 'Alamat depot');
        $jamBuka = cekJam(input('jam_buka'), 'Jam buka');
        $jamTutup = cekJam(input('jam_tutup'), 'Jam tutup');

        if (mb_strlen($namaPengguna) < 3 || mb_strlen($namaPengguna) > 50 || preg_match('/\s/', $namaPengguna)) {
            throw new AppError('Nama pengguna 3–50 karakter dan tidak boleh mengandung spasi.');
        }
        if (strlen($sandi) < 6) {
            throw new AppError('Kata sandi minimal 6 karakter.');
        }
        if (mb_strlen($namaPengelola) > 100 || mb_strlen($namaDepot) > 100) {
            throw new AppError('Nama pengelola / nama depot maksimal 100 karakter.');
        }

        $pdo = db();
        $cek = $pdo->prepare('SELECT 1 FROM pengguna WHERE nama_pengguna = ?');
        $cek->execute([$namaPengguna]);
        if ($cek->fetch()) {
            throw new AppError('Nama pengguna sudah dipakai. Coba nama lain.');
        }

        $idPengguna = uuid();
        $idDepot = uuid();
        $pdo->beginTransaction();
        try {
            $pdo->prepare(
                'INSERT INTO pengguna (id, nama_pengguna, kata_sandi_hash, nama_pengelola) VALUES (?,?,?,?)'
            )->execute([$idPengguna, $namaPengguna, password_hash($sandi, PASSWORD_DEFAULT), $namaPengelola]);

            $pdo->prepare(
                'INSERT INTO depot (id, id_pengguna, nama_depot, alamat, jam_buka, jam_tutup) VALUES (?,?,?,?,?,?)'
            )->execute([$idDepot, $idPengguna, $namaDepot, $alamat, $jamBuka, $jamTutup]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        sukses([
            'pengguna' => [
                'id' => $idPengguna,
                'nama_pengguna' => $namaPengguna,
                'nama_pengelola' => $namaPengelola,
            ],
            'depot' => depotJson($idDepot),
        ]);
        break;

    // POST id_depot, nama_pengelola (opsional), nama_depot, alamat,
    //      jam_buka, jam_tutup, notifikasi_stok_menipis,
    //      notifikasi_sparepart (0/1) -> depot terbaru
    case 'depot_ubah':
        $idDepot = depotAktif();
        $namaDepot = wajib('nama_depot', 'Nama depot');
        $alamat = wajib('alamat', 'Alamat depot');
        $jamBuka = cekJam(input('jam_buka'), 'Jam buka');
        $jamTutup = cekJam(input('jam_tutup'), 'Jam tutup');
        if (mb_strlen($namaDepot) > 100) {
            throw new AppError('Nama depot maksimal 100 karakter.');
        }

        // Nama pengelola boleh tidak dikirim untuk menjaga kompatibilitas.
        $namaPengelola = input('nama_pengelola');
        if ($namaPengelola !== null) {
            if (mb_strlen($namaPengelola) > 100) {
                throw new AppError('Nama pengelola maksimal 100 karakter.');
            }
            $pengguna = db()->prepare('SELECT id_pengguna FROM depot WHERE id = ?');
            $pengguna->execute([$idDepot]);
            $idPengguna = $pengguna->fetchColumn();
            if (!$idPengguna) {
                throw new AppError('Akun pengelola tidak ditemukan.');
            }
            db()->prepare('UPDATE pengguna SET nama_pengelola = ? WHERE id = ?')
                ->execute([$namaPengelola, $idPengguna]);
        }

        // Toggle: kalau tidak dikirim, pertahankan nilai lama
        $lama = depotJson($idDepot);
        $notifStok = input('notifikasi_stok_menipis');
        $notifSpare = input('notifikasi_sparepart');
        $notifStok = $notifStok === null ? (int)$lama['notifikasi_stok_menipis']
            : (in_array((string)$notifStok, ['1', 'true'], true) ? 1 : 0);
        $notifSpare = $notifSpare === null ? (int)$lama['notifikasi_sparepart']
            : (in_array((string)$notifSpare, ['1', 'true'], true) ? 1 : 0);

        db()->prepare(
            'UPDATE depot SET nama_depot = ?, alamat = ?, jam_buka = ?, jam_tutup = ?,
                              notifikasi_stok_menipis = ?, notifikasi_sparepart = ? WHERE id = ?'
        )->execute([$namaDepot, $alamat, $jamBuka, $jamTutup, $notifStok, $notifSpare, $idDepot]);

        // Toggle baru bisa memunculkan pengingat yang tadinya disembunyikan
        periksaPengingat($idDepot);

        sukses(depotJson($idDepot));
        break;

    // GET id_depot -> depot lengkap (dipakai saat auto-login)
    case 'depot_get':
        $idDepot = depotAktif();
        sukses(depotJson($idDepot));
        break;

    default:
        throw new AppError('Aksi tidak dikenal: ' . $aksi);
}
