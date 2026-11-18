// api_service.dart
// Satu-satunya file di Flutter yang berbicara dengan backend PHP.
// Layar cukup memanggil fungsi di sini, contoh: await ApiService.daftarProduk();
//
// Pasang paket dulu:  flutter pub add http

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'services/secure_storage_service.dart';

// Pesan error yang aman langsung ditampilkan ke pengguna
class ApiException implements Exception {
  final String pesan;
  ApiException(this.pesan);

  @override
  String toString() {
    return pesan;
  }
}

class ApiService {
  // Folder PHP di Laragon.
  // Gunakan 10.0.2.2 untuk emulator Android agar bisa akses localhost host machine.
  static const String baseUrl = 'http://10.0.2.2:8000/apkdepot_api';

  // Data login (disimpan selama aplikasi terbuka)
  static PenggunaModel? pengguna;
  static DepotModel? depot;

  static bool get sudahLogin {
    return depot != null;
  }

  // -------------------------------------------------------------------
  // Fungsi inti: kirim permintaan ke PHP dan baca balasannya
  // -------------------------------------------------------------------
  static Future<dynamic> _kirim(
    String file,
    String aksi, {
    Map<String, dynamic>? data,
    bool post = false,
  }) async {
    Map<String, String> query = {'aksi': aksi};
    Map<String, String> isiPost = {};
    Map<String, String> tujuan = post ? isiPost : query;

    // id depot ikut terkirim di setiap permintaan
    if (depot != null) {
      tujuan['id_depot'] = depot!.id;
    }

    // masukkan data, lewati yang kosong
    if (data != null) {
      for (var item in data.entries) {
        if (item.value != null && item.value.toString() != '') {
          tujuan[item.key] = item.value.toString();
        }
      }
    }

    Uri alamat = Uri.parse('$baseUrl/$file').replace(queryParameters: query);

    http.Response respon;
    try {
      if (post) {
        respon = await http.post(alamat, body: isiPost);
      } else {
        respon = await http.get(alamat);
      }
    } catch (e) {
      throw ApiException(
        'Tidak bisa terhubung ke server. Pastikan Laragon (Apache dan MySQL) menyala.',
      );
    }

    dynamic hasil;
    try {
      hasil = json.decode(utf8.decode(respon.bodyBytes));
    } catch (e) {
      throw ApiException('Balasan server tidak valid. Cek file PHP "$file".');
    }

    if (hasil['status'] != 'sukses') {
      throw ApiException(hasil['message'].toString());
    }
    return hasil['data'];
  }

  static void _simpanLogin(dynamic data) {
    pengguna = PenggunaModel.fromJson(data['pengguna']);
    depot = DepotModel.fromJson(data['depot']);
  }

  static Future<void> _simpanKeSecureStorage(dynamic data) async {
    final penggunaData = data['pengguna'];
    final depotData = data['depot'];
    await SecureStorageService.instance.saveSession(
      depotId: depotData['id'],
      penggunaId: penggunaData['id'],
      namaPengguna: penggunaData['nama_pengguna'],
      namaPengelola: penggunaData['nama_pengelola'],
    );
  }

  /// Pulihkan sesi login dari penyimpanan aman (dipanggil saat startup).
  static Future<bool> pulihkanSesi() async {
    final sesi = await SecureStorageService.instance.readSession();
    if (sesi == null) return false;

    // Set minimal data dulu biar UI tidak kosong
    pengguna = PenggunaModel(
      id: sesi.penggunaId,
      namaPengguna: sesi.namaPengguna,
      namaPengelola: sesi.namaPengelola,
    );
    depot = DepotModel(
      id: sesi.depotId,
      namaDepot: '',
      alamat: '',
      jamBuka: '00:00',
      jamTutup: '00:00',
    );

    // Ambil data depot lengkap dari server
    try {
      final data = await _kirim('auth.php', 'depot_get');
      depot = DepotModel.fromJson(data);
      return true;
    } catch (e) {
      // Kalau gagal, session mungkin invalid -> hapus dan return false
      await SecureStorageService.instance.clearSession();
      pengguna = null;
      depot = null;
      return false;
    }
  }

  // ===================================================================
  // LOGIN & DEPOT
  // ===================================================================

  static Future<void> masuk(String namaPengguna, String kataSandi) async {
    var data = await _kirim(
      'auth.php',
      'masuk',
      post: true,
      data: {'nama_pengguna': namaPengguna, 'kata_sandi': kataSandi},
    );
    _simpanLogin(data);
    await _simpanKeSecureStorage(data);
  }

  static Future<void> daftar({
    required String namaPengguna,
    required String kataSandi,
    required String namaPengelola,
    required String namaDepot,
    required String alamat,
    required String jamBuka,
    required String jamTutup,
  }) async {
    var data = await _kirim(
      'auth.php',
      'daftar',
      post: true,
      data: {
        'nama_pengguna': namaPengguna,
        'kata_sandi': kataSandi,
        'nama_pengelola': namaPengelola,
        'nama_depot': namaDepot,
        'alamat': alamat,
        'jam_buka': jamBuka,
        'jam_tutup': jamTutup,
      },
    );
    _simpanLogin(data);
    await _simpanKeSecureStorage(data);
  }

  static Future<void> keluar() async {
    pengguna = null;
    depot = null;
    await SecureStorageService.instance.clearSession();
  }

  /// Simpan profil pengelola dan data depot dalam satu permintaan.
  /// Data pengguna di aplikasi ikut diperbarui setelah server berhasil menyimpan.
  static Future<DepotModel> ubahProfil({
    required String namaPengelola,
    required DepotModel depotBaru,
  }) async {
    final data = depotBaru.toMap();
    data['nama_pengelola'] = namaPengelola;
    final hasil = await _kirim(
      'auth.php',
      'depot_ubah',
      post: true,
      data: data,
    );
    depot = DepotModel.fromJson(hasil);

    final penggunaLama = pengguna;
    if (penggunaLama != null) {
      pengguna = PenggunaModel(
        id: penggunaLama.id,
        namaPengguna: penggunaLama.namaPengguna,
        namaPengelola: namaPengelola,
      );
    }
    return depot!;
  }

  // ===================================================================
  // PRODUK
  // ===================================================================

  static Future<List<ProdukModel>> daftarProduk({String? jenis}) async {
    var data = await _kirim(
      'produk.php',
      'produk_list',
      data: {'jenis': jenis},
    );
    List<ProdukModel> hasil = [];
    for (var item in data) {
      hasil.add(ProdukModel.fromJson(item));
    }
    return hasil;
  }

  // stokAwal hanya dipakai untuk produk galon kosong dan es
  static Future<ProdukModel> tambahProduk(
    ProdukModel produk, {
    int stokAwal = 0,
  }) async {
    Map<String, dynamic> data = produk.toMap();
    data['stok_awal'] = stokAwal;
    var hasil = await _kirim(
      'produk.php',
      'produk_tambah',
      post: true,
      data: data,
    );
    return ProdukModel.fromJson(hasil);
  }

  static Future<ProdukModel> ubahProduk(ProdukModel produk) async {
    Map<String, dynamic> data = produk.toMap();
    data['id'] = produk.id;
    var hasil = await _kirim(
      'produk.php',
      'produk_ubah',
      post: true,
      data: data,
    );
    return ProdukModel.fromJson(hasil);
  }

  // Produk disembunyikan, riwayat transaksinya tetap tersimpan
  static Future<void> nonaktifkanProduk(String id) async {
    await _kirim('produk.php', 'produk_nonaktif', post: true, data: {'id': id});
  }

  // ===================================================================
  // STOK
  // ===================================================================

  static Future<List<StokModel>> daftarStok() async {
    var data = await _kirim('produk.php', 'stok_list');
    List<StokModel> hasil = [];
    for (var item in data) {
      hasil.add(StokModel.fromJson(item));
    }
    return hasil;
  }

  static Future<List<PergerakanStokModel>> riwayatStok(String idProduk) async {
    var data = await _kirim(
      'produk.php',
      'stok_riwayat',
      data: {'id_produk': idProduk},
    );
    List<PergerakanStokModel> hasil = [];
    for (var item in data) {
      hasil.add(PergerakanStokModel.fromJson(item));
    }
    return hasil;
  }

  // Isi jumlah fisik sebenarnya, selisihnya dihitung server
  static Future<StokModel> koreksiStok(
    String idProduk,
    int jumlahBaru,
    String alasan,
  ) async {
    var data = await _kirim(
      'produk.php',
      'stok_koreksi',
      post: true,
      data: {
        'id_produk': idProduk,
        'jumlah_baru': jumlahBaru,
        'alasan': alasan,
      },
    );
    return StokModel.fromJson(data);
  }

  // ===================================================================
  // PEMINJAM
  // ===================================================================

  static Future<List<PeminjamModel>> daftarPeminjam({String? cari}) async {
    var data = await _kirim(
      'produk.php',
      'peminjam_list',
      data: {'cari': cari},
    );
    List<PeminjamModel> hasil = [];
    for (var item in data) {
      hasil.add(PeminjamModel.fromJson(item));
    }
    return hasil;
  }

  static Future<PeminjamModel> tambahPeminjam(
    String nama,
    String alamat,
  ) async {
    var data = await _kirim(
      'produk.php',
      'peminjam_tambah',
      post: true,
      data: {'nama': nama, 'alamat': alamat},
    );
    return PeminjamModel.fromJson(data);
  }

  static Future<PeminjamModel> ubahPeminjam(
    String id,
    String nama,
    String alamat,
    int jumlahPinjam,
  ) async {
    var data = await _kirim(
      'produk.php',
      'peminjam_ubah',
      post: true,
      data: {
        'id': id,
        'nama': nama,
        'alamat': alamat,
        'jumlah_galon_dipinjam': jumlahPinjam,
      },
    );
    return PeminjamModel.fromJson(data);
  }

  // ===================================================================
  // TRANSAKSI
  // ===================================================================

  // dari dan sampai berformat 2026-08-30. aksi = salah satu kunci labelAksi.
  static Future<List<TransaksiModel>> riwayatTransaksi({
    String? dari,
    String? sampai,
    String? aksi,
  }) async {
    var data = await _kirim(
      'transaksi.php',
      'riwayat',
      data: {'dari': dari, 'sampai': sampai, 'jenis_aksi': aksi},
    );
    List<TransaksiModel> hasil = [];
    for (var item in data) {
      hasil.add(TransaksiModel.fromJson(item));
    }
    return hasil;
  }

  static Future<TransaksiModel> detailTransaksi(String id) async {
    var data = await _kirim('transaksi.php', 'detail', data: {'id': id});
    return TransaksiModel.fromJson(data);
  }

  // Satu fungsi untuk 9 aksi. Isi "data" sesuai aksinya:
  //   isi_ulang, beli_galon_kosong, galon_kosong_isi, beli_es:
  //       {'id_produk': ..., 'jumlah': ...}
  //   pinjam_galon_isi:
  //       {'id_produk': ..., 'jumlah': ..., 'id_peminjam': ...}
  //       atau peminjam baru: {'id_produk': ..., 'jumlah': ..., 'nama': ..., 'alamat': ...}
  //   catat_pengeluaran, pendapatan_lain:
  //       {'deskripsi': ..., 'nominal': ..., 'catatan': ...}
  //   ganti_sparepart:
  //       {'id_produk': ..., 'biaya': ...}   (biaya boleh kosong)
  //   kembalikan_galon:
  //       {'id_peminjam': ..., 'jumlah': ...}
  static Future<TransaksiModel> catatTransaksi(
    String aksi,
    Map<String, dynamic> data,
  ) async {
    var hasil = await _kirim('transaksi.php', aksi, post: true, data: data);
    return TransaksiModel.fromJson(hasil);
  }

  // Transaksi tidak dihapus, efeknya dibalik otomatis
  static Future<TransaksiModel> batalkanTransaksi(
    String id,
    String alasan,
  ) async {
    var data = await _kirim(
      'transaksi.php',
      'batalkan',
      post: true,
      data: {'id': id, 'alasan': alasan},
    );
    return TransaksiModel.fromJson(data);
  }

  // ===================================================================
  // BERANDA & LAPORAN (hasilnya Map, ambil nilainya dengan hasil['kunci'])
  // ===================================================================

  // Kunci: pemasukan_hari_ini, pengeluaran_hari_ini, stok_galon_kosong,
  //        stok_es, galon_dipinjam, pengingat (daftar)
  static Future<Map<String, dynamic>> beranda() async {
    return await _kirim('laporan.php', 'beranda');
  }

  // Kunci: total_pemasukan, total_pengeluaran, selisih, jumlah_transaksi, transaksi
  static Future<Map<String, dynamic>> laporanHarian(String tanggal) async {
    return await _kirim('laporan.php', 'harian', data: {'tanggal': tanggal});
  }

  // periode = minggu, bulan, atau tahun
  // Kunci: total_pemasukan, total_pengeluaran, selisih, grafik_harian
  static Future<Map<String, dynamic>> laporanRingkasan(
    String periode,
    String tanggal,
  ) async {
    return await _kirim(
      'laporan.php',
      'ringkasan',
      data: {'periode': periode, 'tanggal': tanggal},
    );
  }

  // Alamat untuk mengunduh laporan CSV (dibuka di tab baru)
  static String urlEkspor(String dari, String sampai) {
    String idDepot = depot?.id ?? '';
    return '$baseUrl/laporan.php?aksi=ekspor&id_depot=$idDepot&dari=$dari&sampai=$sampai';
  }

  // ===================================================================
  // PENGINGAT
  // ===================================================================

  // status = belum_dibaca, dibaca, atau selesai. Kosong = semua.
  static Future<List<PengingatModel>> daftarPengingat({String? status}) async {
    var data = await _kirim(
      'laporan.php',
      'pengingat_list',
      data: {'status': status},
    );
    List<PengingatModel> hasil = [];
    for (var item in data) {
      hasil.add(PengingatModel.fromJson(item));
    }
    return hasil;
  }

  static Future<void> ubahStatusPengingat(String id, String status) async {
    await _kirim(
      'laporan.php',
      'pengingat_ubah',
      post: true,
      data: {'id': id, 'status': status},
    );
  }

  // Minta server memeriksa stok dan sparepart sekarang
  static Future<void> cekPengingat() async {
    await _kirim('laporan.php', 'pengingat_cek');
  }
}
