// =====================================================================
// Fungsi pembantu parsing
// =====================================================================

String? _str(dynamic v) => v?.toString();

int _int(dynamic v, [int bawaan = 0]) {
  if (v == null) return bawaan;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ??
      double.tryParse(v.toString())?.toInt() ??
      bawaan;
}

int? _intN(dynamic v) => v == null ? null : _int(v);

double _dbl(dynamic v, [double bawaan = 0]) {
  if (v == null) return bawaan;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? bawaan;
}

double? _dblN(dynamic v) => v == null ? null : _dbl(v);

DateTime? _tgl(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

bool _bool(dynamic v) => v == true || v == 1 || v == '1';

/// Format tanggal untuk dikirim ke backend: yyyy-MM-dd
String formatTanggalKirim(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// =====================================================================
// ENUM
// =====================================================================

/// 5 jenis produk (Fitur 1)
enum JenisProduk {
  jenisAir('jenis_air', 'Jenis Air'),
  galonKosong('galon_kosong', 'Galon Kosong'),
  galonKosongIsi('galon_kosong_isi', 'Galon Kosong + Isi'),
  es('es', 'Es'),
  sparepart('sparepart', 'Sparepart');

  final String value; // nilai yang dikirim/diterima dari backend
  final String label; // teks untuk ditampilkan di layar
  const JenisProduk(this.value, this.label);

  /// Semua jenis kecuali sparepart wajib punya harga
  bool get wajibHarga => this != JenisProduk.sparepart;

  /// Hanya sparepart yang punya masa pakai & tanggal terakhir diganti
  bool get wajibMasaPakai => this == JenisProduk.sparepart;

  /// Hanya galon kosong & es yang punya stok dan ambang batas stok
  bool get punyaStok =>
      this == JenisProduk.galonKosong || this == JenisProduk.es;

  static JenisProduk fromValue(String v) =>
      JenisProduk.values.firstWhere((e) => e.value == v);
}

/// 9 jenis aksi transaksi (Fitur 3). `value` = nama aksi yang dikirim ke backend.
enum JenisAksi {
  isiUlang('isi_ulang', 'Isi Ulang'),
  beliGalonKosong('beli_galon_kosong', 'Beli Galon'),
  galonKosongIsi('galon_kosong_isi', 'Beli Galon + Isi'),
  beliEs('beli_es', 'Beli Es'),
  pinjamGalonIsi('pinjam_galon_isi', 'Pinjam Galon + Isi'),
  catatPengeluaran('catat_pengeluaran', 'Pengeluaran'),
  pendapatanLain('pendapatan_lain', 'Pendapatan Lainnya'),
  gantiSparepart('ganti_sparepart', 'Ganti Sparepart'),
  kembalikanGalon('kembalikan_galon', 'Kembali Galon');

  final String value;
  final String label;
  const JenisAksi(this.value, this.label);

  static JenisAksi fromValue(String v) =>
      JenisAksi.values.firstWhere((e) => e.value == v);
}

// =====================================================================
// MODEL
// =====================================================================

/// Akun pengelola (tabel `pengguna`). Kata sandi tidak pernah dikirim ke app.
class PenggunaModel {
  final String id;
  final String namaPengguna;
  final String namaPengelola;

  PenggunaModel({
    required this.id,
    required this.namaPengguna,
    required this.namaPengelola,
  });

  factory PenggunaModel.fromJson(Map<String, dynamic> j) => PenggunaModel(
    id: j['id'].toString(),
    namaPengguna: j['nama_pengguna'].toString(),
    namaPengelola: j['nama_pengelola'].toString(),
  );
}

/// Biodata depot + pengaturan notifikasi (tabel `depot`)
class DepotModel {
  final String id;
  final String namaDepot;
  final String alamat;
  final String jamBuka; // 'HH:mm'
  final String jamTutup; // 'HH:mm'
  final bool notifikasiStokMenipis;
  final bool notifikasiSparepart;

  DepotModel({
    required this.id,
    required this.namaDepot,
    required this.alamat,
    required this.jamBuka,
    required this.jamTutup,
    this.notifikasiStokMenipis = true,
    this.notifikasiSparepart = true,
  });

  factory DepotModel.fromJson(Map<String, dynamic> j) => DepotModel(
    id: j['id'].toString(),
    namaDepot: j['nama_depot'].toString(),
    alamat: j['alamat'].toString(),
    jamBuka: j['jam_buka'].toString(),
    jamTutup: j['jam_tutup'].toString(),
    notifikasiStokMenipis: _bool(j['notifikasi_stok_menipis']),
    notifikasiSparepart: _bool(j['notifikasi_sparepart']),
  );

  /// Data untuk menyimpan perubahan profil
  Map<String, dynamic> toMap() => {
    'nama_depot': namaDepot,
    'alamat': alamat,
    'jam_buka': jamBuka,
    'jam_tutup': jamTutup,
    'notifikasi_stok_menipis': notifikasiStokMenipis ? 1 : 0,
    'notifikasi_sparepart': notifikasiSparepart ? 1 : 0,
  };

  DepotModel copyWith({
    String? namaDepot,
    String? alamat,
    String? jamBuka,
    String? jamTutup,
    bool? notifikasiStokMenipis,
    bool? notifikasiSparepart,
  }) => DepotModel(
    id: id,
    namaDepot: namaDepot ?? this.namaDepot,
    alamat: alamat ?? this.alamat,
    jamBuka: jamBuka ?? this.jamBuka,
    jamTutup: jamTutup ?? this.jamTutup,
    notifikasiStokMenipis: notifikasiStokMenipis ?? this.notifikasiStokMenipis,
    notifikasiSparepart: notifikasiSparepart ?? this.notifikasiSparepart,
  );
}

/// Master produk (tabel `produk`)
class ProdukModel {
  final String id;
  final String namaProduk;
  final JenisProduk jenis;
  final double? harga; // null untuk sparepart
  final int? masaPakaiHari; // hanya sparepart
  final DateTime? terakhirDiganti; // hanya sparepart
  final int? ambangStokMinimum; // hanya galon kosong & es
  final bool aktif;

  ProdukModel({
    required this.id,
    required this.namaProduk,
    required this.jenis,
    this.harga,
    this.masaPakaiHari,
    this.terakhirDiganti,
    this.ambangStokMinimum,
    this.aktif = true,
  });

  factory ProdukModel.fromJson(Map<String, dynamic> j) => ProdukModel(
    id: j['id'].toString(),
    namaProduk: j['nama_produk'].toString(),
    jenis: JenisProduk.fromValue(j['jenis'].toString()),
    harga: _dblN(j['harga']),
    masaPakaiHari: _intN(j['masa_pakai_hari']),
    terakhirDiganti: _tgl(j['terakhir_diganti']),
    ambangStokMinimum: _intN(j['ambang_stok_minimum']),
    aktif: j['aktif'] == null ? true : _bool(j['aktif']),
  );

  /// Data untuk tambah/ubah produk. Hanya mengirim field yang relevan
  /// dengan jenisnya (harga untuk non-sparepart, masa pakai untuk sparepart).
  Map<String, dynamic> toMap() => {
    'nama_produk': namaProduk,
    'jenis': jenis.value,
    if (jenis.wajibHarga) 'harga': harga,
    if (jenis.wajibMasaPakai) 'masa_pakai_hari': masaPakaiHari,
    if (jenis.wajibMasaPakai && terakhirDiganti != null)
      'terakhir_diganti': formatTanggalKirim(terakhirDiganti!),
    if (jenis.punyaStok) 'ambang_stok_minimum': ambangStokMinimum,
  };
}

/// Angka stok per produk (tabel `stok` digabung dengan data produknya)
class StokModel {
  final String idProduk;
  final String namaProduk;
  final JenisProduk jenis;
  final int jumlahSaatIni;
  final int? ambangStokMinimum;

  StokModel({
    required this.idProduk,
    required this.namaProduk,
    required this.jenis,
    required this.jumlahSaatIni,
    this.ambangStokMinimum,
  });

  factory StokModel.fromJson(Map<String, dynamic> j) => StokModel(
    idProduk: j['id_produk'].toString(),
    namaProduk: j['nama_produk'].toString(),
    jenis: JenisProduk.fromValue(j['jenis'].toString()),
    jumlahSaatIni: _int(j['jumlah_saat_ini']),
    ambangStokMinimum: _intN(j['ambang_stok_minimum']),
  );

  /// True kalau stok sudah di bawah/sama dengan ambang batas (bawaan 5)
  bool get menipis => jumlahSaatIni <= (ambangStokMinimum ?? 5);
}

/// Riwayat perubahan stok (tabel `pergerakan_stok`)
class PergerakanStokModel {
  final String id;
  final String idProduk;
  final String? idTransaksi; // null kalau dari koreksi manual
  final int perubahan; // negatif = berkurang, positif = bertambah
  final String jenisPergerakan; // 'otomatis' atau 'koreksi_manual'
  final String? keterangan;
  final DateTime? dibuatPada;

  PergerakanStokModel({
    required this.id,
    required this.idProduk,
    this.idTransaksi,
    required this.perubahan,
    required this.jenisPergerakan,
    this.keterangan,
    this.dibuatPada,
  });

  factory PergerakanStokModel.fromJson(Map<String, dynamic> j) =>
      PergerakanStokModel(
        id: j['id'].toString(),
        idProduk: j['id_produk'].toString(),
        idTransaksi: _str(j['id_transaksi']),
        perubahan: _int(j['perubahan']),
        jenisPergerakan: j['jenis_pergerakan'].toString(),
        keterangan: _str(j['keterangan']),
        dibuatPada: _tgl(j['dibuat_pada']),
      );
}

/// Orang yang meminjam galon depot (tabel `peminjam`)
class PeminjamModel {
  final String id;
  final String nama;
  final String alamat;
  final int jumlahGalonDipinjam;

  PeminjamModel({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.jumlahGalonDipinjam,
  });

  factory PeminjamModel.fromJson(Map<String, dynamic> j) => PeminjamModel(
    id: j['id'].toString(),
    nama: j['nama'].toString(),
    alamat: j['alamat'].toString(),
    jumlahGalonDipinjam: _int(j['jumlah_galon_dipinjam']),
  );

  bool get masihMeminjam => jumlahGalonDipinjam > 0;
}

/// Satu catatan transaksi (tabel `transaksi`), lengkap dengan nama produk
/// dan nama peminjam supaya riwayat bisa langsung ditampilkan.
class TransaksiModel {
  final String id;
  final JenisAksi jenisAksi;
  final String? idProduk;
  final String? namaProduk;
  final String? idPeminjam;
  final String? namaPeminjam;
  final String? deskripsi; // untuk pengeluaran & pendapatan lainnya
  final int jumlah;
  final double? hargaSatuan;
  final double total;
  final String tipeArusKas; // 'pemasukan' atau 'pengeluaran'
  final String status; // 'aktif' atau 'dibatalkan'
  final DateTime? dibatalkanPada;
  final String? alasanBatal;
  final String? catatan;
  final DateTime? dibuatPada;

  TransaksiModel({
    required this.id,
    required this.jenisAksi,
    this.idProduk,
    this.namaProduk,
    this.idPeminjam,
    this.namaPeminjam,
    this.deskripsi,
    required this.jumlah,
    this.hargaSatuan,
    required this.total,
    required this.tipeArusKas,
    required this.status,
    this.dibatalkanPada,
    this.alasanBatal,
    this.catatan,
    this.dibuatPada,
  });

  factory TransaksiModel.fromJson(Map<String, dynamic> j) => TransaksiModel(
    id: j['id'].toString(),
    jenisAksi: JenisAksi.fromValue(j['jenis_aksi'].toString()),
    idProduk: _str(j['id_produk']),
    namaProduk: _str(j['nama_produk']),
    idPeminjam: _str(j['id_peminjam']),
    namaPeminjam: _str(j['nama_peminjam']),
    deskripsi: _str(j['deskripsi']),
    jumlah: _int(j['jumlah'], 1),
    hargaSatuan: _dblN(j['harga_satuan']),
    total: _dbl(j['total']),
    tipeArusKas: j['tipe_arus_kas'].toString(),
    status: j['status'].toString(),
    dibatalkanPada: _tgl(j['dibatalkan_pada']),
    alasanBatal: _str(j['alasan_batal']),
    catatan: _str(j['catatan']),
    dibuatPada: _tgl(j['dibuat_pada']),
  );

  bool get pemasukan => tipeArusKas == 'pemasukan';
  bool get dibatalkan => status == 'dibatalkan';
  bool get bisaDibatalkan => !dibatalkan;
}

/// Notifikasi stok menipis / sparepart jatuh tempo (tabel `pengingat`)
class PengingatModel {
  final String id;
  final String jenis; // 'stok_menipis' atau 'sparepart_jatuh_tempo'
  final String idProduk;
  final String? namaProduk;
  final String pesan;
  final String status; // 'belum_dibaca', 'dibaca', 'selesai'
  final DateTime? dibuatPada;

  PengingatModel({
    required this.id,
    required this.jenis,
    required this.idProduk,
    this.namaProduk,
    required this.pesan,
    required this.status,
    this.dibuatPada,
  });

  factory PengingatModel.fromJson(Map<String, dynamic> j) => PengingatModel(
    id: j['id'].toString(),
    jenis: j['jenis'].toString(),
    idProduk: j['id_produk'].toString(),
    namaProduk: _str(j['nama_produk']),
    pesan: j['pesan'].toString(),
    status: j['status'].toString(),
    dibuatPada: _tgl(j['dibuat_pada']),
  );

  bool get stokMenipis => jenis == 'stok_menipis';
}
