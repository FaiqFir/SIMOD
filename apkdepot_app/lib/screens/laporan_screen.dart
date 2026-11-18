// screens/laporan_screen.dart
// Tab "Laporan" (Laporan Operasional): Harian, Mingguan, Bulanan, Tahunan.
// Data dari ApiService.laporanHarian() dan ApiService.laporanRingkasan().
// Tombol "Ekspor" membuka tautan unduhan CSV (butuh paket url_launcher):
//   flutter pub add url_launcher
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import '../api_service.dart';
import '../models.dart';
import 'login_screen.dart'; // WarnaMod, appBarMod, tampilSnack
import 'transaksi_screen.dart'; // formatRupiah, ikonAksi

const Color _hijau = Color(0xFF2E9E5B);
const Color _merah = Color(0xFFE53935);
const Color _warnaMasuk = Color(0xFF2196F3);
const Color _warnaKeluar = Color(0xFFFFB4B4);

const List<String> _bulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];
const List<String> _hariPendek = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];
const List<String> _hari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

enum _Periode {
  harian('Harian', 'Harian'),
  mingguan('Mingguan', 'Mingguan'),
  bulanan('Bulanan', 'Bulanan'),
  tahunan('Tahunan', 'Tahunan');

  final String label;
  final String labelLaba;
  const _Periode(this.label, this.labelLaba);
}

class _Titik {
  final DateTime tgl;
  final num masuk;
  final num keluar;
  _Titik(this.tgl, this.masuk, this.keluar);
}

class _Bar {
  final String label;
  final String tooltip;
  final num masuk;
  final num keluar;
  _Bar(this.label, this.tooltip, this.masuk, this.keluar);
}

num _angka(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime _hanyaTanggal(DateTime d) => DateTime(d.year, d.month, d.day);

String _singkat(num n) {
  final a = n.abs();
  final tanda = n < 0 ? '-' : '';
  if (a >= 1000000) {
    final v = (a / 1000000);
    return '$tanda${v.toStringAsFixed(v >= 10 ? 0 : 1)} jt';
  }
  if (a >= 1000)
    return '$tanda${(a / 1000).toStringAsFixed(a >= 10000 ? 0 : 1)} rb';
  return '$tanda${a.round()}';
}

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  _Periode _periode = _Periode.harian;
  DateTime _tanggal = _hanyaTanggal(DateTime.now());

  Map<String, dynamic>? _ringkasan; // total + grafik periode terpilih
  Map<String, dynamic>? _harian; // hanya untuk tab Harian
  bool _memuat = true;
  String? _error;
  int _tiket = 0; // untuk mengabaikan balasan lama

  @override
  void initState() {
    super.initState();
    _muat();
  }

  // ------------------------------------------------------------------
  // Rentang tanggal periode terpilih
  // ------------------------------------------------------------------
  DateTime get _senin =>
      _tanggal.subtract(Duration(days: _tanggal.weekday - 1));

  DateTime get _awal => switch (_periode) {
    _Periode.harian => _tanggal,
    _Periode.mingguan => _senin,
    _Periode.bulanan => DateTime(_tanggal.year, _tanggal.month, 1),
    _Periode.tahunan => DateTime(_tanggal.year, 1, 1),
  };

  DateTime get _akhir => switch (_periode) {
    _Periode.harian => _tanggal,
    _Periode.mingguan => _senin.add(const Duration(days: 6)),
    _Periode.bulanan => DateTime(_tanggal.year, _tanggal.month + 1, 0),
    _Periode.tahunan => DateTime(_tanggal.year, 12, 31),
  };

  bool get _bisaMaju => _akhir.isBefore(_hanyaTanggal(DateTime.now()));

  String get _labelRentang {
    String d(DateTime x) => '${x.day} ${_bulan[x.month - 1].substring(0, 3)}';
    switch (_periode) {
      case _Periode.harian:
        final t = _tanggal;
        return '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]} ${t.year}';
      case _Periode.mingguan:
        return '${d(_awal)} - ${d(_akhir)} ${_akhir.year}';
      case _Periode.bulanan:
        return '${_bulan[_tanggal.month - 1]} ${_tanggal.year}';
      case _Periode.tahunan:
        return '${_tanggal.year}';
    }
  }

  void _geser(int arah) {
    setState(() {
      switch (_periode) {
        case _Periode.harian:
          _tanggal = _tanggal.add(Duration(days: arah));
        case _Periode.mingguan:
          _tanggal = _tanggal.add(Duration(days: 7 * arah));
        case _Periode.bulanan:
          _tanggal = DateTime(_tanggal.year, _tanggal.month + arah, 1);
        case _Periode.tahunan:
          _tanggal = DateTime(_tanggal.year + arah, 1, 1);
      }
      final hariIni = _hanyaTanggal(DateTime.now());
      if (_tanggal.isAfter(hariIni)) _tanggal = hariIni;
    });
    _muat();
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (hasil != null) {
      setState(() => _tanggal = _hanyaTanggal(hasil));
      _muat();
    }
  }

  // ------------------------------------------------------------------
  Future<void> _muat() async {
    final tiket = ++_tiket;
    setState(() {
      _error = null;
      if (_ringkasan == null) _memuat = true;
    });
    final tgl = formatTanggalKirim(_tanggal);
    try {
      Map<String, dynamic> ringkasan;
      Map<String, dynamic>? harian;
      switch (_periode) {
        case _Periode.harian:
          harian = await ApiService.laporanHarian(tgl);
          ringkasan = harian;
        case _Periode.mingguan:
          ringkasan = await ApiService.laporanRingkasan('minggu', tgl);
        case _Periode.bulanan:
          ringkasan = await ApiService.laporanRingkasan('bulan', tgl);
        case _Periode.tahunan:
          ringkasan = await ApiService.laporanRingkasan('tahun', tgl);
      }
      if (!mounted || tiket != _tiket) return;
      setState(() {
        _ringkasan = ringkasan;
        _harian = harian;
      });
    } on ApiException catch (e) {
      if (mounted && tiket == _tiket) setState(() => _error = e.pesan);
    } catch (e) {
      if (mounted && tiket == _tiket) {
        setState(() => _error = 'Terjadi kesalahan: $e');
      }
    } finally {
      if (mounted && tiket == _tiket) setState(() => _memuat = false);
    }
  }

  Future<void> _ekspor() async {
    final url = ApiService.urlEkspor(
      formatTanggalKirim(_awal),
      formatTanggalKirim(_akhir),
    );
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted)
        tampilSnack(context, 'Tidak bisa membuka tautan ekspor');
    } catch (_) {
      if (mounted) tampilSnack(context, 'Tidak bisa membuka tautan ekspor');
    }
  }

  // ------------------------------------------------------------------
  // Data total (dari tab harian atau ringkasan)
  // ------------------------------------------------------------------
  Map<String, dynamic>? get _sumberTotal =>
      _periode == _Periode.harian ? _harian : _ringkasan;

  List<_Titik> _parseGrafik() {
    final raw = _ringkasan?['grafik_harian'];
    if (raw is! List) return [];
    final hasil = <_Titik>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final t = DateTime.tryParse(item['tanggal']?.toString() ?? '');
      if (t == null) continue;
      hasil.add(
        _Titik(
          _hanyaTanggal(t),
          _angka(item['pemasukan'] ?? item['total_pemasukan']),
          _angka(item['pengeluaran'] ?? item['total_pengeluaran']),
        ),
      );
    }
    return hasil;
  }

    List<_Bar> _susunBar() {
    if (_periode == _Periode.harian) {
      // Harian: 24 batang per jam. Pakai grafik_jam kalau server mengirim,
      // kalau tidak, hitung sendiri dari daftar transaksi hari itu.
      final masuk = List<num>.filled(24, 0);
      final keluar = List<num>.filled(24, 0);

      final raw = _harian?['grafik_jam'];
      if (raw is List && raw.isNotEmpty) {
        for (final item in raw) {
          if (item is! Map) continue;
          final jam = _angka(item['jam']).toInt();
          if (jam < 0 || jam > 23) continue;
          masuk[jam] += _angka(item['pemasukan']);
          keluar[jam] += _angka(item['pengeluaran']);
        }
      } else {
        final trx = _harian?['transaksi'];
        if (trx is List) {
          for (final t in trx) {
            if (t is! Map) continue;
            if (t['status']?.toString() == 'dibatalkan') continue;
            final waktu = DateTime.tryParse(
                (t['dibuat_pada']?.toString() ?? '').replaceFirst(' ', 'T'));
            if (waktu == null) continue;
            final nilai = _angka(t['total']);
            if (t['tipe_arus_kas']?.toString() == 'pengeluaran') {
              keluar[waktu.hour] += nilai;
            } else {
              masuk[waktu.hour] += nilai;
            }
          }
        }
      }

      return [
        for (var jam = 0; jam < 24; jam++)
          () {
            final label = '${jam.toString().padLeft(2, '0')}:00';
            return _Bar(label, label, masuk[jam], keluar[jam]);
          }(),
      ];
    }

    // Mingguan, Bulanan, Tahunan: use daily aggregated data (grafik_harian)
    final titik = _parseGrafik();
    num masukPada(bool Function(DateTime) cocok) => titik
        .where((t) => cocok(t.tgl))
        .fold<num>(0, (a, t) => a + t.masuk);
    num keluarPada(bool Function(DateTime) cocok) => titik
        .where((t) => cocok(t.tgl))
        .fold<num>(0, (a, t) => a + t.keluar);

    final bars = <_Bar>[];
    switch (_periode) {
      case _Periode.mingguan:
        final senin = _senin;
        for (int i = 0; i < 7; i++) {
          final d = senin.add(Duration(days: i));
          bool sama(DateTime x) => x == d;
          bars.add(_Bar(
            _hariPendek[i],
            '${_hari[i]} ${d.day} ${_bulan[d.month - 1]}',
            masukPada(sama),
            keluarPada(sama),
          ));
        }
      case _Periode.bulanan:
        final jumlahHari = DateTime(_tanggal.year, _tanggal.month + 1, 0).day;
        for (int i = 1; i <= jumlahHari; i++) {
          final d = DateTime(_tanggal.year, _tanggal.month, i);
          bool sama(DateTime x) => x == d;
          final tampil = i == 1 || i % 5 == 0;
          bars.add(_Bar(
            tampil ? '$i' : '',
            '$i ${_bulan[_tanggal.month - 1]}',
            masukPada(sama),
            keluarPada(sama),
          ));
        }
      case _Periode.tahunan:
        for (int m = 1; m <= 12; m++) {
          bool sama(DateTime x) => x.year == _tanggal.year && x.month == m;
          bars.add(_Bar(
            _bulan[m - 1].substring(0, 3),
            '${_bulan[m - 1]} ${_tanggal.year}',
            masukPada(sama),
            keluarPada(sama),
          ));
        }
      case _Periode.harian:
        return const [];
    }
    return bars;
  }
  String get _judulGrafik => switch (_periode) {
    _Periode.harian => 'Tren Pemasukan Harian',
    _Periode.mingguan => 'Tren Pemasukan Mingguan',
    _Periode.bulanan => 'Tren Pemasukan Bulanan',
    _Periode.tahunan => 'Tren Pemasukan Tahunan',
  };

  // ==================================================================
  // TAMPILAN
  // ==================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod(
        'Laporan Operasional',
        aksi: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _ekspor,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 17),
              label: const Text(
                'Ekspor',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _barisPeriode(),
          _navigator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              color: WarnaMod.biru,
              child: _isi(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisPeriode() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          for (final p in _Periode.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (_periode == p) return;
                    setState(() {
                      _periode = p;
                      _ringkasan = null;
                      _harian = null;
                    });
                    _muat();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _periode == p ? WarnaMod.biru : WarnaMod.latar,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _periode == p ? WarnaMod.biru : WarnaMod.garis,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _periode == p
                            ? Colors.white
                            : WarnaMod.teksRedup,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navigator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _geser(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: WarnaMod.biru,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pilihTanggal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: WarnaMod.teksRedup,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _labelRentang,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _bisaMaju ? () => _geser(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: WarnaMod.biru,
          ),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_memuat && _ringkasan == null) {
      return ListView(
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: WarnaMod.biru)),
        ],
      );
    }
    if (_error != null && _ringkasan == null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: WarnaMod.teksRedup,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WarnaMod.teksRedup),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: _muat,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      );
    }

    final total = _sumberTotal ?? _ringkasan ?? {};
    final masuk = _angka(total['total_pemasukan']);
    final keluar = _angka(total['total_pengeluaran']);
    final laba = total['selisih'] != null
        ? _angka(total['selisih'])
        : masuk - keluar;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            _kartuTotal('Pemasukan', masuk, _hijau, Icons.south_west_rounded),
            const SizedBox(width: 10),
            _kartuTotal(
              'Pengeluaran',
              keluar,
              _merah,
              Icons.north_east_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _kartuLaba(laba, total),
        const SizedBox(height: 14),
        _kartuGrafik(),
        if (_periode == _Periode.harian) ...[
          const SizedBox(height: 18),
          _daftarHarian(),
        ],
      ],
    );
  }

  Widget _kartuTotal(String label, num nilai, Color warna, IconData ikon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: warna.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(ikon, size: 14, color: warna),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: WarnaMod.teksRedup,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Rp ${formatRupiah(nilai)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: warna,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuLaba(num laba, Map<String, dynamic> total) {
    final jumlah = total['jumlah_transaksi'];
    final rugi = laba < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: rugi
              ? const [Color(0xFFC62828), Color(0xFFE57373)]
              : const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        boxShadow: [
          BoxShadow(
            color: (rugi ? _merah : WarnaMod.biru).withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laba Bersih ${_periode.labelLaba}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rp ${formatRupiah(laba)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (jumlah != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_angka(jumlah).toInt()} transaksi',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

// ------------------------------------------------------------------
  // Grafik batang buatan sendiri (tanpa paket tambahan)
  // ------------------------------------------------------------------
  Widget _kartuGrafik() {
    final bars = _susunBar();
    num maks = 0;
    for (final b in bars) {
      if (b.masuk > maks) maks = b.masuk;
      if (b.keluar > maks) maks = b.keluar;
    }
    final skalaMaks = maks > 0 ? maks : 1;
    const tinggiMaks = 120.0;
    final harian = _periode == _Periode.harian;
    final rapat = bars.length > 14 && !harian;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _judulGrafik,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _legenda('Masuk', _warnaMasuk),
              const SizedBox(width: 10),
              _legenda('Keluar', _warnaKeluar),
            ],
          ),
          const SizedBox(height: 10),
          if (maks == 0 && !harian)
            const Text(
              'Belum ada transaksi pada periode ini.',
              style: TextStyle(fontSize: 11.5, color: WarnaMod.teksRedup),
            )
          else
            SizedBox(
              height: tinggiMaks + 22,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final lebarIsi = harian
                      ? math.max(bars.length * 44.0, constraints.maxWidth)
                      : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics:
                        harian ? null : const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: lebarIsi,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final b in bars)
                            Expanded(
                              child: Tooltip(
                                triggerMode: TooltipTriggerMode.tap,
                                message:
                                    '${b.tooltip}\nMasuk: Rp ${formatRupiah(b.masuk)}\nKeluar: Rp ${formatRupiah(b.keluar)}',
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _batang(b.masuk, skalaMaks, tinggiMaks,
                                            _warnaMasuk, rapat),
                                        SizedBox(width: rapat ? 1 : 2),
                                        _batang(b.keluar, skalaMaks,
                                            tinggiMaks, _warnaKeluar, rapat),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    SizedBox(
                                      height: 13,
                                      child: FittedBox(
                                        child: Text(
                                          b.label,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: WarnaMod.teksRedup,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _batang(
    num nilai,
    num maks,
    double tinggiMaks,
    Color warna,
    bool rapat,
  ) {
    final tinggi = maks == 0 ? 0.0 : (nilai / maks) * tinggiMaks;
    return Container(
      width: rapat ? 3 : 8,
      height: nilai > 0 ? tinggi.clamp(3.0, tinggiMaks).toDouble() : 2,
      decoration: BoxDecoration(
        color: nilai > 0 ? warna : WarnaMod.garis.withOpacity(0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
  Widget _legenda(String teks, Color warna) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          teks,
          style: const TextStyle(fontSize: 10.5, color: WarnaMod.teksRedup),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Daftar transaksi pada hari terpilih (hanya tab Harian)
  // ------------------------------------------------------------------
  Widget _daftarHarian() {
    final raw = _harian?['transaksi'];
    final list = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          if (m['status']?.toString() == 'dibatalkan') continue;
          list.add(m);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaksi Hari Ini',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 34,
                  color: WarnaMod.teksRedup,
                ),
                SizedBox(height: 8),
                Text(
                  'Tidak ada transaksi pada tanggal ini',
                  style: TextStyle(fontSize: 12.5, color: WarnaMod.teksRedup),
                ),
              ],
            ),
          )
        else
          for (final m in list) _barisTransaksi(m),
      ],
    );
  }

  Widget _barisTransaksi(Map<String, dynamic> m) {
    JenisAksi? aksi;
    try {
      aksi = JenisAksi.fromValue(m['jenis_aksi'].toString());
    } catch (_) {}
    final pemasukan = m['tipe_arus_kas']?.toString() == 'pemasukan';
    final kembali = aksi == JenisAksi.kembalikanGalon;
    final warna = kembali ? WarnaMod.biru : (pemasukan ? _hijau : _merah);
    final total = _angka(m['total']);
    final judul =
        (m['nama_produk'] ??
                m['deskripsi'] ??
                m['nama_peminjam'] ??
                aksi?.label ??
                '-')
            .toString();
    final jam = DateTime.tryParse(m['dibuat_pada']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: warna.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              aksi == null ? Icons.receipt_long_outlined : ikonAksi[aksi],
              size: 18,
              color: warna,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    if (aksi != null) aksi.label,
                    if (jam != null)
                      '${jam.hour.toString().padLeft(2, '0')}:${jam.minute.toString().padLeft(2, '0')}',
                  ].join(' - '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: WarnaMod.teksRedup,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            Text(
              '${pemasukan ? '+' : '-'} Rp ${formatRupiah(total)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: warna,
              ),
            ),
        ],
      ),
    );
  }
}
