// transaksi_screen.dart
// Tab Transaksi: grid 9 aksi + transaksi terbaru
// FormTransaksiScreen: satu form untuk 9 aksi
// DaftarTransaksiScreen: riwayat lengkap + filter + detail + batalkan
// Data lewat ApiService; layar hanya mengurus tampilan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../models.dart';
import 'login_screen.dart'; // WarnaMod, TombolUtama, LabelInput, dekorInput, ...

// Pembantu bersama
const Map<JenisAksi, IconData> ikonAksi = {
  JenisAksi.isiUlang: Icons.autorenew_rounded,
  JenisAksi.beliGalonKosong: Icons.add_circle_outline_rounded,
  JenisAksi.galonKosongIsi: Icons.local_drink_outlined,
  JenisAksi.beliEs: Icons.ac_unit_rounded,
  JenisAksi.pinjamGalonIsi: Icons.shopping_cart_outlined,
  JenisAksi.catatPengeluaran: Icons.arrow_circle_up_rounded,
  JenisAksi.pendapatanLain: Icons.arrow_circle_down_rounded,
  JenisAksi.gantiSparepart: Icons.settings_outlined,
  JenisAksi.kembalikanGalon: Icons.assignment_return_outlined,
};

/// Format rupiah: 785000 -> "785.000"
String formatRupiah(num n) {
  final negatif = n < 0;
  final s = n.abs().round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${negatif ? '-' : ''}$buf';
}

String _dua(int n) => n.toString().padLeft(2, '0');
String formatTanggal(DateTime d) => '${_dua(d.day)}/${_dua(d.month)}/${d.year}';
String formatTanggalJam(DateTime d) =>
    '${formatTanggal(d)} ${_dua(d.hour)}:${_dua(d.minute)}';

String waktuRelatif(DateTime? t) {
  if (t == null) return '';
  final selisih = DateTime.now().difference(t);
  if (selisih.inMinutes < 1) return 'baru saja';
  if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
  if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
  if (selisih.inHours < 48) return 'kemarin';
  return formatTanggal(t);
}

Color _warnaTransaksi(TransaksiModel t) {
  if (t.dibatalkan) return const Color(0xFF90A4AE);
  if (t.jenisAksi == JenisAksi.kembalikanGalon) return WarnaMod.biru;
  return t.pemasukan ? const Color(0xFF2E9E5B) : WarnaMod.error;
}

// 1. TAB TRANSAKSI
class TransaksiScreen extends StatefulWidget {
  /// Diisi dari grid "Aksi Cepat" di Beranda -> form langsung terbuka
  final ValueNotifier<JenisAksi?>? aksiDipilih;

  const TransaksiScreen({super.key, this.aksiDipilih});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  List<TransaksiModel> _terbaru = [];
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.aksiDipilih?.addListener(_cekAksiDariBeranda);
    _muat();
  }

  @override
  void dispose() {
    widget.aksiDipilih?.removeListener(_cekAksiDariBeranda);
    super.dispose();
  }

  void _cekAksiDariBeranda() {
    final aksi = widget.aksiDipilih?.value;
    if (aksi == null) return;
    widget.aksiDipilih!.value = null; // reset supaya tidak terbuka dua kali
    _bukaForm(aksi);
  }

  Future<void> _muat() async {
    setState(() {
      _error = null;
      if (_terbaru.isEmpty) _memuat = true;
    });
    try {
      final sekarang = DateTime.now();
      final hasil = await ApiService.riwayatTransaksi(
        dari: formatTanggalKirim(sekarang.subtract(const Duration(days: 30))),
        sampai: formatTanggalKirim(sekarang),
      );
      if (!mounted) return;
      setState(() => _terbaru = hasil.take(5).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _bukaForm(JenisAksi aksi) async {
    final berhasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormTransaksiScreen(aksi: aksi)),
    );
    if (berhasil == true) _muat();
  }

  Future<void> _bukaDaftar() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DaftarTransaksiScreen()));
    _muat();
  }

  Future<void> _bukaDetail(TransaksiModel t) async {
    final berubah = await bukaDetailTransaksi(context, t);
    if (berubah) _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod('Pencatatan Transaksi'),
      body: RefreshIndicator(
        onRefresh: _muat,
        color: WarnaMod.biru,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Pilih jenis pencatatan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WarnaMod.teksRedup,
              ),
            ),
            const SizedBox(height: 10),
            _gridAksi(),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transaksi Terbaru',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: WarnaMod.teks,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _bukaDaftar,
                  child: const Text(
                    'Lihat semua',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_memuat)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: WarnaMod.biru),
                ),
              )
            else if (_error != null)
              _kosong(Icons.cloud_off_rounded, _error!, tombolUlang: true)
            else if (_terbaru.isEmpty)
              _kosong(
                Icons.receipt_long_outlined,
                'Belum ada transaksi. Pilih salah satu jenis di atas untuk mulai mencatat.',
              )
            else
              for (final t in _terbaru)
                ItemTransaksi(t: t, onTap: () => _bukaDetail(t)),
            if (!_memuat && _terbaru.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: _bukaDaftar,
                  child: const Text(
                    'Daftar Transaksi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: WarnaMod.biru,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gridAksi() {
    const aksi = JenisAksi.values;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: aksi.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) {
        final a = aksi[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _bukaForm(a),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: WarnaMod.biru.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(ikonAksi[a], size: 21, color: WarnaMod.biru),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    a.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: WarnaMod.teks,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _kosong(IconData ikon, String teks, {bool tombolUlang = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          Icon(ikon, size: 40, color: WarnaMod.teksRedup),
          const SizedBox(height: 10),
          Text(
            teks,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: WarnaMod.teksRedup),
          ),
          if (tombolUlang) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _muat,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ],
      ),
    );
  }
}

// BARIS TRANSAKSI (dipakai di tab dan di daftar lengkap)
class ItemTransaksi extends StatelessWidget {
  final TransaksiModel t;
  final VoidCallback onTap;

  const ItemTransaksi({super.key, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final warna = _warnaTransaksi(t);
    final nominalManual =
        t.jenisAksi == JenisAksi.catatPengeluaran ||
        t.jenisAksi == JenisAksi.pendapatanLain;

    final judul =
        t.namaProduk ?? t.deskripsi ?? t.namaPeminjam ?? t.jenisAksi.label;

    String sub;
    if (nominalManual) {
      sub = (t.catatan ?? '').trim();
    } else {
      sub = '${t.jumlah} Pcs';
      if (t.namaPeminjam != null && t.namaPeminjam != judul) {
        sub += ' • ${t.namaPeminjam}';
      }
    }

    String nominal;
    if (t.total <= 0) {
      nominal = '';
    } else {
      nominal = '${t.pemasukan ? '' : '- '}Rp ${formatRupiah(t.total)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: warna.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t.dibatalkan ? 'Dibatalkan' : t.jenisAksi.label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: warna,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              waktuRelatif(t.dibuatPada),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: WarnaMod.teksRedup,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: t.dibatalkan
                              ? WarnaMod.teksRedup
                              : WarnaMod.teks,
                          decoration: t.dibatalkan
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: WarnaMod.teksRedup,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (nominal.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Text(
                      nominal,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: t.dibatalkan ? WarnaMod.teksRedup : warna,
                        decoration: t.dibatalkan
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// DETAIL TRANSAKSI + BATALKAN
// Mengembalikan true kalau ada perubahan (transaksi dibatalkan)
Future<bool> bukaDetailTransaksi(BuildContext context, TransaksiModel t) async {
  final hasil = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DetailTransaksiSheet(t: t),
  );
  return hasil == true;
}

class _DetailTransaksiSheet extends StatefulWidget {
  final TransaksiModel t;
  const _DetailTransaksiSheet({required this.t});

  @override
  State<_DetailTransaksiSheet> createState() => _DetailTransaksiSheetState();
}

class _DetailTransaksiSheetState extends State<_DetailTransaksiSheet> {
  bool _membatalkan = false;
  String? _error;

  Future<String?> _tanyaAlasan() {
    final ctrl = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text(
            'Batalkan transaksi?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stok dan kas akan dikembalikan otomatis. Transaksi tetap tersimpan dengan status dibatalkan.',
                style: TextStyle(fontSize: 12.5, color: WarnaMod.teksRedup),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: dekorInput('Alasan pembatalan')
                    .copyWith(errorText: err),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kembali'),
            ),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) {
                  setD(() => err = 'Alasan wajib diisi');
                  return;
                }
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: const Text(
                'Batalkan Transaksi',
                style: TextStyle(
                  color: WarnaMod.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batalkan() async {
    final alasan = await _tanyaAlasan();
    if (alasan == null) return;
    setState(() {
      _membatalkan = true;
      _error = null;
    });
    try {
      await ApiService.batalkanTransaksi(widget.t.id, alasan);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _membatalkan = false);
    }
  }

  Widget _baris(
    String label,
    String nilai, {
    Color? warna,
    bool tebal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: WarnaMod.teksRedup),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: TextStyle(
                fontSize: 13,
                fontWeight: tebal ? FontWeight.w800 : FontWeight.w600,
                color: warna ?? WarnaMod.teks,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final warna = _warnaTransaksi(t);
    final nominalManual =
        t.jenisAksi == JenisAksi.catatPengeluaran ||
        t.jenisAksi == JenisAksi.pendapatanLain;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WarnaMod.garis,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: warna.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(ikonAksi[t.jenisAksi], color: warna, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.jenisAksi.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        t.dibuatPada == null
                            ? ''
                            : formatTanggalJam(t.dibuatPada!),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: WarnaMod.teksRedup,
                        ),
                      ),
                    ],
                  ),
                ),
                if (t.dibatalkan)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: warna.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Dibatalkan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: warna,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 6),
            if (t.namaProduk != null) _baris('Produk', t.namaProduk!),
            if (t.deskripsi != null && t.deskripsi!.isNotEmpty)
              _baris('Deskripsi', t.deskripsi!),
            if (t.namaPeminjam != null) _baris('Peminjam', t.namaPeminjam!),
            if (!nominalManual) _baris('Jumlah', '${t.jumlah} Pcs'),
            if (t.hargaSatuan != null && !nominalManual)
              _baris('Harga satuan', 'Rp ${formatRupiah(t.hargaSatuan!)}'),
            if (t.total > 0)
              _baris(
                'Total',
                'Rp ${formatRupiah(t.total)}',
                warna: warna,
                tebal: true,
              ),
            if (t.catatan != null && t.catatan!.isNotEmpty)
              _baris('Catatan', t.catatan!),
            if (t.dibatalkan) ...[
              if (t.dibatalkanPada != null)
                _baris('Dibatalkan pada', formatTanggalJam(t.dibatalkanPada!)),
              if (t.alasanBatal != null && t.alasanBatal!.isNotEmpty)
                _baris('Alasan', t.alasanBatal!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: WarnaMod.error),
              ),
            ],
            if (t.bisaDibatalkan) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _membatalkan ? null : _batalkan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WarnaMod.error,
                    side: const BorderSide(color: WarnaMod.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _membatalkan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text(
                    'Batalkan Transaksi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 3. DAFTAR TRANSAKSI (riwayat lengkap)
class DaftarTransaksiScreen extends StatefulWidget {
  const DaftarTransaksiScreen({super.key});

  @override
  State<DaftarTransaksiScreen> createState() => _DaftarTransaksiScreenState();
}

class _DaftarTransaksiScreenState extends State<DaftarTransaksiScreen> {
  late DateTimeRange _rentang;
  JenisAksi? _filter;
  List<TransaksiModel> _data = [];
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final sekarang = DateTime.now();
    _rentang = DateTimeRange(
      start: DateTime(
        sekarang.year,
        sekarang.month,
        sekarang.day,
      ).subtract(const Duration(days: 29)),
      end: DateTime(sekarang.year, sekarang.month, sekarang.day),
    );
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final hasil = await ApiService.riwayatTransaksi(
        dari: formatTanggalKirim(_rentang.start),
        sampai: formatTanggalKirim(_rentang.end),
        aksi: _filter?.value,
      );
      if (mounted) setState(() => _data = hasil);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _pilihRentang() async {
    final hasil = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _rentang,
    );
    if (hasil != null) {
      setState(() => _rentang = hasil);
      _muat();
    }
  }

  Future<void> _bukaDetail(TransaksiModel t) async {
    final berubah = await bukaDetailTransaksi(context, t);
    if (berubah) _muat();
  }

  @override
  Widget build(BuildContext context) {
    num masuk = 0, keluar = 0;
    for (final t in _data) {
      if (t.dibatalkan) continue;
      if (t.jenisAksi == JenisAksi.kembalikanGalon) continue;
      if (t.pemasukan) {
        masuk += t.total;
      } else {
        keluar += t.total;
      }
    }

    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod('Daftar Transaksi'),
      body: Column(
        children: [
          // filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pilihRentang,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: WarnaMod.garis),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_rounded,
                          size: 18,
                          color: WarnaMod.biru,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${formatTanggal(_rentang.start)}  -  ${formatTanggal(_rentang.end)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: WarnaMod.teksRedup,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('Semua', _filter == null, () {
                        setState(() => _filter = null);
                        _muat();
                      }),
                      for (final a in JenisAksi.values)
                        _chip(a.label, _filter == a, () {
                          setState(() => _filter = a);
                          _muat();
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ringkasan
          if (!_memuat && _error == null && _data.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _ringkas('Pemasukan', masuk, const Color(0xFF2E9E5B)),
                  const SizedBox(width: 10),
                  _ringkas('Pengeluaran', keluar, WarnaMod.error),
                ],
              ),
            ),
          // daftar
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              color: WarnaMod.biru,
              child: _memuat
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: CircularProgressIndicator(
                            color: WarnaMod.biru,
                          ),
                        ),
                      ],
                    )
                  : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 44,
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
                      ],
                    )
                  : _data.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 44,
                          color: WarnaMod.teksRedup,
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Tidak ada transaksi pada filter ini',
                            style: TextStyle(color: WarnaMod.teksRedup),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _data.length,
                      itemBuilder: (_, i) => ItemTransaksi(
                        t: _data[i],
                        onTap: () => _bukaDetail(_data[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool aktif, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: aktif,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: aktif ? Colors.white : WarnaMod.teks,
        ),
        selectedColor: WarnaMod.biru,
        backgroundColor: Colors.white,
        side: BorderSide(color: aktif ? WarnaMod.biru : WarnaMod.garis),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _ringkas(String label, num nilai, Color warna) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: warna.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: WarnaMod.teksRedup),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Rp ${formatRupiah(nilai)}',
                style: TextStyle(
                  fontSize: 15,
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
}

// 2. FORM TRANSAKSI (9 aksi, field menyesuaikan jenis aksi)
class FormTransaksiScreen extends StatefulWidget {
  final JenisAksi aksi;
  const FormTransaksiScreen({super.key, required this.aksi});

  @override
  State<FormTransaksiScreen> createState() => _FormTransaksiScreenState();
}

class _FormTransaksiScreenState extends State<FormTransaksiScreen> {
  static const String _idBaru = '__peminjam_baru__';

  final _formKey = GlobalKey<FormState>();
  final _jumlahCtrl = TextEditingController(text: '1');
  final _nominalCtrl = TextEditingController();
  final _biayaCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  bool _memuat = true;
  bool _menyimpan = false;
  String? _errorMuat;

  List<ProdukModel> _produk = [];
  ProdukModel? _produkDipilih;
  List<PeminjamModel> _peminjam = [];
  PeminjamModel? _peminjamDipilih;
  int _resetPeminjam =
      0; // dinaikkan supaya dropdown kembali kosong saat dialog dibatalkan

  JenisAksi get _aksi => widget.aksi;

  // konfigurasi per aksi
  JenisProduk? get _jenisProduk => switch (_aksi) {
    JenisAksi.isiUlang || JenisAksi.pinjamGalonIsi => JenisProduk.jenisAir,
    JenisAksi.beliGalonKosong => JenisProduk.galonKosong,
    JenisAksi.galonKosongIsi => JenisProduk.galonKosongIsi,
    JenisAksi.beliEs => JenisProduk.es,
    JenisAksi.gantiSparepart => JenisProduk.sparepart,
    _ => null,
  };

  String get _labelProduk => switch (_aksi) {
    JenisAksi.beliGalonKosong => 'Galon Kosong',
    JenisAksi.galonKosongIsi => 'Galon Kosong + Isi',
    JenisAksi.beliEs => 'Jenis Es',
    JenisAksi.gantiSparepart => 'Nama Sparepart',
    _ => 'Jenis Air',
  };

  bool get _pakaiProduk => _jenisProduk != null;
  bool get _formNominal =>
      _aksi == JenisAksi.catatPengeluaran || _aksi == JenisAksi.pendapatanLain;
  bool get _gantiSparepart => _aksi == JenisAksi.gantiSparepart;
  bool get _kembali => _aksi == JenisAksi.kembalikanGalon;
  bool get _pinjam => _aksi == JenisAksi.pinjamGalonIsi;
  bool get _pakaiPeminjam => _pinjam || _kembali;
  bool get _pakaiJumlah => !_formNominal && !_gantiSparepart;
  bool get _pakaiCatatan => _formNominal || _kembali;
  bool get _pakaiHarga => _pakaiProduk && !_gantiSparepart;

  int get _jumlah => int.tryParse(_jumlahCtrl.text) ?? 0;
  num get _nominal => num.tryParse(_nominalCtrl.text) ?? 0;
  num get _biaya => num.tryParse(_biayaCtrl.text) ?? 0;

  num get _total {
    if (_formNominal) return _nominal;
    if (_gantiSparepart) return _biaya;
    if (_kembali) return 0;
    return (_produkDipilih?.harga ?? 0) * _jumlah;
  }

  String get _labelTotal => switch (_aksi) {
    JenisAksi.catatPengeluaran => 'Total Pengeluaran',
    JenisAksi.pendapatanLain => 'Total Pemasukan',
    _ => 'Total Harga',
  };

  String get _labelNominal => _aksi == JenisAksi.pendapatanLain
      ? 'Jumlah Pemasukan'
      : 'Jumlah Pengeluaran';

  int? get _maksJumlah =>
      _kembali ? _peminjamDipilih?.jumlahGalonDipinjam : null;

  // siklus hidup
  @override
  void initState() {
    super.initState();
    _muatData();
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _nominalCtrl.dispose();
    _biayaCtrl.dispose();
    _deskripsiCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatData() async {
    setState(() {
      _memuat = true;
      _errorMuat = null;
    });
    try {
      if (_jenisProduk != null) {
        final list = await ApiService.daftarProduk(jenis: _jenisProduk!.value);
        _produk = list.where((p) => p.aktif).toList();
        if (_produk.length == 1) _produkDipilih = _produk.first;
      }
      if (_pakaiPeminjam) {
        final list = await ApiService.daftarPeminjam();
        _peminjam = _kembali
            ? list.where((p) => p.masihMeminjam).toList()
            : list;
      }
    } on ApiException catch (e) {
      _errorMuat = e.pesan;
    } catch (e) {
      _errorMuat = 'Terjadi kesalahan: $e';
    }
    if (mounted) setState(() => _memuat = false);
  }

  // peminjam baru (quick-add)
  Future<void> _tambahPeminjamBaru() async {
    final namaCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final kunci = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Peminjam Baru',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Form(
          key: kunci,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelInput('Nama Peminjam'),
              TextFormField(
                controller: namaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: dekorInput('Contoh: Sari'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              const LabelInput('Alamat'),
              TextFormField(
                controller: alamatCtrl,
                maxLines: 2,
                decoration: dekorInput('Jalan, nomor, RT/RW'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Alamat wajib diisi'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (kunci.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final baru = await ApiService.tambahPeminjam(
          namaCtrl.text.trim(),
          alamatCtrl.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _peminjam = [..._peminjam, baru];
          _peminjamDipilih = baru;
        });
      } on ApiException catch (e) {
        if (mounted) tampilSnack(context, e.pesan);
      } catch (e) {
        if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
      }
    }
    namaCtrl.dispose();
    alamatCtrl.dispose();
    if (mounted && _peminjamDipilih == null) setState(() => _resetPeminjam++);
  }

  // simpan
  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final data = <String, dynamic>{};
    if (_pakaiProduk) data['id_produk'] = _produkDipilih!.id;
    if (_pakaiJumlah) data['jumlah'] = _jumlah;
    if (_pakaiPeminjam) data['id_peminjam'] = _peminjamDipilih!.id;
    if (_formNominal) {
      data['deskripsi'] = _deskripsiCtrl.text.trim();
      data['nominal'] = _nominal;
    }
    if (_gantiSparepart && _biaya > 0) data['biaya'] = _biaya;
    if (_pakaiCatatan) data['catatan'] = _catatanCtrl.text.trim();

    setState(() => _menyimpan = true);
    try {
      await ApiService.catatTransaksi(_aksi.value, data);
      if (!mounted) return;
      tampilSnack(context, 'Transaksi Anda berhasil', error: false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  // potongan tampilan
  Widget _dropdownProduk() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelInput(_labelProduk),
        DropdownButtonFormField<String>(
          value: _produkDipilih?.id,
          isExpanded: true,
          decoration: dekorInput(
            _produk.isEmpty ? 'Belum ada produk' : 'Pilih $_labelProduk',
          ),
          items: [
            for (final p in _produk)
              DropdownMenuItem(
                value: p.id,
                child: Text(
                  (_pakaiHarga && p.harga != null)
                      ? '${p.namaProduk}  •  Rp ${formatRupiah(p.harga!)}'
                      : p.namaProduk,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          onChanged: (id) => setState(
            () => _produkDipilih = _produk.firstWhere((p) => p.id == id),
          ),
          validator: (v) => v == null
              ? (_produk.isEmpty
                    ? 'Tambahkan dulu produknya di menu Produk'
                    : 'Pilih $_labelProduk')
              : null,
        ),
        if (_gantiSparepart && _produkDipilih != null) _infoSparepart(),
      ],
    );
  }

  Widget _infoSparepart() {
    final p = _produkDipilih!;
    final teks = StringBuffer();
    if (p.masaPakaiHari != null) {
      teks.write('Masa pakai ${p.masaPakaiHari} hari');
    }
    if (p.terakhirDiganti != null) {
      if (teks.isNotEmpty) teks.write('  •  ');
      teks.write('Terakhir diganti ${formatTanggal(p.terakhirDiganti!)}');
    }
    if (teks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        teks.toString(),
        style: const TextStyle(fontSize: 11.5, color: WarnaMod.teksRedup),
      ),
    );
  }

  Widget _dropdownPeminjam() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelInput(_kembali ? 'Nama Pelanggan' : 'Pilih Peminjam'),
        DropdownButtonFormField<String>(
          key: ValueKey('pm-${_peminjamDipilih?.id}-$_resetPeminjam'),
          value: _peminjamDipilih?.id,
          isExpanded: true,
          decoration: dekorInput(
            _kembali && _peminjam.isEmpty
                ? 'Tidak ada galon yang sedang dipinjam'
                : 'Pilih peminjam',
          ),
          items: [
            for (final p in _peminjam)
              DropdownMenuItem(
                value: p.id,
                child: Text(
                  _kembali
                      ? '${p.nama}  •  ${p.jumlahGalonDipinjam} galon'
                      : p.nama,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (_pinjam)
              const DropdownMenuItem(
                value: _idBaru,
                child: Text(
                  '+ Tambah peminjam baru',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WarnaMod.biru,
                  ),
                ),
              ),
          ],
          onChanged: (id) {
            if (id == _idBaru) {
              _tambahPeminjamBaru();
            } else {
              setState(() {
                _peminjamDipilih = _peminjam.firstWhere((p) => p.id == id);
              });
            }
          },
          validator: (v) => v == null ? 'Peminjam wajib dipilih' : null,
        ),
        if (_pinjam && _peminjamDipilih != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${_peminjamDipilih!.alamat}  •  sedang meminjam ${_peminjamDipilih!.jumlahGalonDipinjam} galon',
              style: const TextStyle(fontSize: 11.5, color: WarnaMod.teksRedup),
            ),
          ),
      ],
    );
  }

  Widget _tombolBulat(IconData ikon, VoidCallback? onTap) {
    return Material(
      color: onTap == null
          ? WarnaMod.garis.withOpacity(0.5)
          : WarnaMod.biru.withOpacity(0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            ikon,
            size: 20,
            color: onTap == null ? WarnaMod.teksRedup : WarnaMod.biru,
          ),
        ),
      ),
    );
  }

  Widget _stepperJumlah() {
    final maks = _maksJumlah;
    void ubah(int d) {
      var baru = _jumlah + d;
      if (baru < 1) baru = 1;
      if (maks != null && baru > maks) baru = maks;
      setState(() => _jumlahCtrl.text = '$baru');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelInput(_kembali ? 'Jumlah Galon Dikembalikan' : 'Jumlah'),
        Row(
          children: [
            _tombolBulat(
              Icons.remove_rounded,
              _jumlah > 1 ? () => ubah(-1) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _jumlahCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: dekorInput('1').copyWith(suffixText: 'Pcs'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '') ?? 0;
                  if (n < 1) return 'Minimal 1';
                  if (maks != null && n > maks) {
                    return 'Maksimal $maks (jumlah yang dipinjam)';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            _tombolBulat(
              Icons.add_rounded,
              (maks != null && _jumlah >= maks) ? null : () => ubah(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hargaBaca(String label, num? nilai) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelInput(label),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: WarnaMod.latar,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WarnaMod.garis),
          ),
          child: Text(
            nilai == null ? '-' : 'Rp ${formatRupiah(nilai)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _kolomUang(
    TextEditingController c,
    String label,
    String hint, {
    bool wajib = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelInput(label),
        TextFormField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: dekorInput(hint).copyWith(prefixText: 'Rp '),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = num.tryParse(v ?? '') ?? 0;
            if (wajib && n <= 0) return '$label harus lebih dari 0';
            return null;
          },
        ),
      ],
    );
  }

  Widget _barisTotal() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: WarnaMod.biru.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _labelTotal,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WarnaMod.teks,
              ),
            ),
          ),
          Text(
            'Rp ${formatRupiah(_total)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WarnaMod.biru,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formIsi() {
    final w = <Widget>[];
    void tambah(Widget x) {
      if (w.isNotEmpty) w.add(const SizedBox(height: 16));
      w.add(x);
    }

    if (_pakaiPeminjam) tambah(_dropdownPeminjam());
    if (_pakaiProduk) tambah(_dropdownProduk());
    if (_pakaiJumlah) tambah(_stepperJumlah());
    if (_pakaiHarga) {
      tambah(_hargaBaca('Harga per Pcs', _produkDipilih?.harga));
    }
    if (_formNominal) {
      tambah(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabelInput(
              _aksi == JenisAksi.pendapatanLain
                  ? 'Deskripsi Pemasukan'
                  : 'Deskripsi Pengeluaran',
            ),
            TextFormField(
              controller: _deskripsiCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: dekorInput(
                _aksi == JenisAksi.pendapatanLain
                    ? 'Contoh: Jual barang bekas'
                    : 'Contoh: Beli tutup galon',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Deskripsi wajib diisi'
                  : null,
            ),
          ],
        ),
      );
      tambah(_kolomUang(_nominalCtrl, _labelNominal, '50000'));
    }
    if (_gantiSparepart) {
      tambah(
        _kolomUang(
          _biayaCtrl,
          'Biaya Penggantian (Opsional)',
          '0',
          wajib: false,
        ),
      );
    }
    if (_pakaiCatatan) {
      tambah(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LabelInput('Catatan (Opsional)'),
            TextFormField(
              controller: _catatanCtrl,
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: dekorInput('Masukkan catatan tambahan jika ada...'),
            ),
          ],
        ),
      );
    }
    if (!_kembali) {
      w.add(const SizedBox(height: 18));
      w.add(_barisTotal());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: w);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod(_aksi.label),
      body: SafeArea(
        child: _memuat
            ? const Center(
                child: CircularProgressIndicator(color: WarnaMod.biru),
              )
            : _errorMuat != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 44,
                        color: WarnaMod.teksRedup,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMuat!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: WarnaMod.teksRedup),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _muatData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: WarnaMod.garis.withOpacity(0.7),
                              ),
                            ),
                            child: _formIsi(),
                          ),
                          const SizedBox(height: 18),
                          TombolUtama(
                            teks: 'Simpan Transaksi',
                            memuat: _menyimpan,
                            onTekan: _simpan,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
