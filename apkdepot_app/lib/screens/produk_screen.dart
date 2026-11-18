// screens/produk_screen.dart
// Tab "Produk" (Manajemen Produk):
//   - Tab "Daftar"   : kartu stok (Ubah Stok) + daftar produk (edit / hapus)
//   - Tab "Catatan"  : daftar peminjam yang masih membawa galon
//   - FormProdukScreen : tambah / ubah produk
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../models.dart';
import 'login_screen.dart'; // WarnaMod, TombolUtama, LabelInput, dekorInput, ...
import 'transaksi_screen.dart'; // formatRupiah, formatTanggal

String _masaPakai(int hari) {
  if (hari >= 30 && hari % 30 == 0) return '${hari ~/ 30} bulan';
  return '$hari hari';
}

// =====================================================================
// TAB PRODUK
// =====================================================================
class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  int _tab = 0; // 0 = Daftar, 1 = Catatan

  List<ProdukModel> _produk = [];
  List<StokModel> _stok = [];
  List<PeminjamModel> _peminjam = [];
  JenisProduk? _filter;
  final _cariCtrl = TextEditingController();
  String _cari = '';

  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _error = null;
      if (_produk.isEmpty && _peminjam.isEmpty) _memuat = true;
    });
    try {
      final hasil = await Future.wait([
        ApiService.daftarProduk(),
        ApiService.daftarStok(),
        ApiService.daftarPeminjam(),
      ]);
      if (!mounted) return;
      setState(() {
        _produk = (hasil[0] as List<ProdukModel>)
            .where((p) => p.aktif)
            .toList();
        _stok = (hasil[1] as List<StokModel>)
            .where((s) => s.jenis.punyaStok)
            .toList();
        _peminjam = (hasil[2] as List<PeminjamModel>)
            .where((p) => p.masihMeminjam)
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  // ------------------------------------------------------------------
  Future<void> _bukaForm([ProdukModel? produk]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormProdukScreen(produk: produk)),
    );
    if (ok == true) _muat();
  }

  Future<void> _hapus(ProdukModel p) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus produk?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${p.namaProduk}" akan disembunyikan dari daftar. Riwayat transaksinya tetap tersimpan.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: WarnaMod.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ApiService.nonaktifkanProduk(p.id);
      if (!mounted) return;
      tampilSnack(context, 'Produk berhasil dihapus', error: false);
      _muat();
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    }
  }

  Future<void> _ubahStok(StokModel s) async {
    final jumlahCtrl = TextEditingController(text: '${s.jumlahSaatIni}');
    final alasanCtrl = TextEditingController();
    final kunci = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Ubah Stok ${s.namaProduk}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Form(
          key: kunci,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stok tercatat saat ini: ${s.jumlahSaatIni}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: WarnaMod.teksRedup,
                ),
              ),
              const SizedBox(height: 12),
              const LabelInput('Jumlah Stok Fisik Sebenarnya'),
              TextFormField(
                controller: jumlahCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: dekorInput('0'),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Isi jumlah stok' : null,
              ),
              const SizedBox(height: 12),
              const LabelInput('Alasan Koreksi'),
              TextFormField(
                controller: alasanCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: dekorInput('Contoh: Hitung ulang stok fisik'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Alasan wajib diisi'
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

    final jumlahBaru = int.tryParse(jumlahCtrl.text);
    final alasan = alasanCtrl.text.trim();
    jumlahCtrl.dispose();
    alasanCtrl.dispose();
    if (ok != true || jumlahBaru == null) return;

    try {
      await ApiService.koreksiStok(s.idProduk, jumlahBaru, alasan);
      if (!mounted) return;
      tampilSnack(context, 'Stok berhasil diperbarui', error: false);
      _muat();
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    }
  }

  Future<void> _ubahPeminjam(PeminjamModel p) async {
    final namaCtrl = TextEditingController(text: p.nama);
    final alamatCtrl = TextEditingController(text: p.alamat);
    final jumlahCtrl = TextEditingController(text: '${p.jumlahGalonDipinjam}');
    final kunci = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Data Peminjam',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: kunci,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelInput('Nama'),
                TextFormField(
                  controller: namaCtrl,
                  decoration: dekorInput('Nama peminjam'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                const LabelInput('Alamat'),
                TextFormField(
                  controller: alamatCtrl,
                  maxLines: 2,
                  decoration: dekorInput('Alamat'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Alamat wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                const LabelInput('Galon Belum Kembali'),
                TextFormField(
                  controller: jumlahCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: dekorInput('0'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Isi jumlah' : null,
                ),
              ],
            ),
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

    final nama = namaCtrl.text.trim();
    final alamat = alamatCtrl.text.trim();
    final jumlah = int.tryParse(jumlahCtrl.text) ?? p.jumlahGalonDipinjam;
    namaCtrl.dispose();
    alamatCtrl.dispose();
    jumlahCtrl.dispose();
    if (ok != true) return;

    try {
      await ApiService.ubahPeminjam(p.id, nama, alamat, jumlah);
      if (!mounted) return;
      tampilSnack(context, 'Data peminjam diperbarui', error: false);
      _muat();
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    }
  }

  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod(
        'Manajemen Produk',
        aksi: [
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => _bukaForm(),
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
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Tambah',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                _tabChip('Daftar', 0),
                const SizedBox(width: 8),
                _tabChip('Catatan', 1),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              color: WarnaMod.biru,
              child: _memuat
                  ? ListView(
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: CircularProgressIndicator(
                            color: WarnaMod.biru,
                          ),
                        ),
                      ],
                    )
                  : _error != null
                  ? _tampilanError()
                  : (_tab == 0 ? _tabDaftar() : _tabCatatan()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final aktif = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? WarnaMod.biru : WarnaMod.latar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: aktif ? WarnaMod.biru : WarnaMod.garis),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: aktif ? Colors.white : WarnaMod.teksRedup,
          ),
        ),
      ),
    );
  }

  Widget _tampilanError() {
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
            _error ?? '',
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

  // =================================================================
  // TAB DAFTAR
  // =================================================================
  Widget _tabDaftar() {
    final tampil = _filter == null
        ? _produk
        : _produk.where((p) => p.jenis == _filter).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        for (final s in _stok) _kartuStok(s),
        if (_stok.isNotEmpty) const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chipFilter('Semua', _filter == null, () {
                setState(() => _filter = null);
              }),
              for (final j in JenisProduk.values)
                _chipFilter(j.label, _filter == j, () {
                  setState(() => _filter = j);
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (tampil.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: const [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 42,
                  color: WarnaMod.teksRedup,
                ),
                SizedBox(height: 10),
                Text(
                  'Belum ada produk. Ketuk "Tambah" untuk menambahkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: WarnaMod.teksRedup),
                ),
              ],
            ),
          )
        else
          for (final p in tampil) _barisProduk(p),
      ],
    );
  }

  Widget _chipFilter(String label, bool aktif, VoidCallback onTap) {
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

  Widget _kartuStok(StokModel s) {
    final menipis =
        s.ambangStokMinimum != null && s.jumlahSaatIni <= s.ambangStokMinimum!;
    final warna = menipis ? WarnaMod.error : const Color(0xFF2E9E5B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: menipis
              ? WarnaMod.error.withOpacity(0.35)
              : WarnaMod.garis.withOpacity(0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stok ${s.namaProduk}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: WarnaMod.teks,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: warna.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  menipis ? 'Menipis' : 'Normal',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: warna,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${s.jumlahSaatIni}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: menipis ? WarnaMod.error : WarnaMod.teks,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'pcs',
                style: TextStyle(fontSize: 13, color: WarnaMod.teksRedup),
              ),
              const Spacer(),
              if (s.ambangStokMinimum != null)
                Text(
                  'Batas minimum ${s.ambangStokMinimum}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WarnaMod.teksRedup,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () => _ubahStok(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: WarnaMod.biru,
                side: const BorderSide(color: WarnaMod.biru),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text(
                'Ubah Stok',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisProduk(ProdukModel p) {
    final sparepart = p.jenis == JenisProduk.sparepart;
    final kanan = sparepart
        ? (p.masaPakaiHari == null ? '-' : _masaPakai(p.masaPakaiHari!))
        : (p.harga == null ? '-' : 'Rp ${formatRupiah(p.harga!)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.namaProduk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: WarnaMod.teks,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.jenis.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: WarnaMod.biru,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Text(
            kanan,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: WarnaMod.biru,
            ),
          ),
          const SizedBox(width: 6),
          _ikonAksi(Icons.edit_outlined, WarnaMod.biru, () => _bukaForm(p)),
          const SizedBox(width: 6),
          _ikonAksi(
            Icons.delete_outline_rounded,
            WarnaMod.error,
            () => _hapus(p),
          ),
        ],
      ),
    );
  }

  Widget _ikonAksi(IconData ikon, Color warna, VoidCallback onTap) {
    return Material(
      color: warna.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(ikon, size: 17, color: warna),
        ),
      ),
    );
  }

  // =================================================================
  // TAB CATATAN (peminjam yang belum mengembalikan galon)
  // =================================================================
  Widget _tabCatatan() {
    final q = _cari.toLowerCase();
    final tampil = q.isEmpty
        ? _peminjam
        : _peminjam
              .where(
                (p) =>
                    p.nama.toLowerCase().contains(q) ||
                    p.alamat.toLowerCase().contains(q),
              )
              .toList();
    final total = _peminjam.fold<int>(0, (a, p) => a + p.jumlahGalonDipinjam);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        TextField(
          controller: _cariCtrl,
          onChanged: (v) => setState(() => _cari = v.trim()),
          decoration: dekorInput(
            'Cari nama peminjam...',
            prefix: const Icon(
              Icons.search_rounded,
              size: 20,
              color: WarnaMod.teksRedup,
            ),
            suffix: _cari.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _cariCtrl.clear();
                      setState(() => _cari = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (_peminjam.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFFB7791F),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_peminjam.length} peminjam • $total galon belum kembali',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A5A0B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (tampil.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 42,
                  color: WarnaMod.teksRedup,
                ),
                const SizedBox(height: 10),
                Text(
                  _peminjam.isEmpty
                      ? 'Tidak ada galon yang sedang dipinjam.'
                      : 'Peminjam tidak ditemukan.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WarnaMod.teksRedup,
                  ),
                ),
              ],
            ),
          )
        else
          for (final p in tampil) _barisPeminjam(p),
      ],
    );
  }

  Widget _barisPeminjam(PeminjamModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _ubahPeminjam(p),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: WarnaMod.teks,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.alamat,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: WarnaMod.teksRedup,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: WarnaMod.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.jumlahGalonDipinjam} Galon',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: WarnaMod.error,
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

// =====================================================================
// FORM TAMBAH / UBAH PRODUK
// =====================================================================
class FormProdukScreen extends StatefulWidget {
  /// null = tambah produk baru, isi = ubah produk
  final ProdukModel? produk;
  const FormProdukScreen({super.key, this.produk});

  @override
  State<FormProdukScreen> createState() => _FormProdukScreenState();
}

class _FormProdukScreenState extends State<FormProdukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _masaCtrl = TextEditingController();
  final _ambangCtrl = TextEditingController(text: '5');
  final _stokAwalCtrl = TextEditingController(text: '0');

  JenisProduk _jenis = JenisProduk.jenisAir;
  bool _satuanBulan = true; // masa pakai dalam bulan (true) atau hari (false)
  DateTime? _terakhirDiganti;
  bool _menyimpan = false;

  bool get _ubah => widget.produk != null;

  @override
  void initState() {
    super.initState();
    final p = widget.produk;
    if (p != null) {
      _jenis = p.jenis;
      _namaCtrl.text = p.namaProduk;
      if (p.harga != null) _hargaCtrl.text = p.harga!.round().toString();
      if (p.masaPakaiHari != null) {
        final h = p.masaPakaiHari!;
        if (h >= 30 && h % 30 == 0) {
          _satuanBulan = true;
          _masaCtrl.text = '${h ~/ 30}';
        } else {
          _satuanBulan = false;
          _masaCtrl.text = '$h';
        }
      }
      _terakhirDiganti = p.terakhirDiganti;
      if (p.ambangStokMinimum != null) {
        _ambangCtrl.text = '${p.ambangStokMinimum}';
      }
    } else {
      _terakhirDiganti = DateTime.now();
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _masaCtrl.dispose();
    _ambangCtrl.dispose();
    _stokAwalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _terakhirDiganti ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (hasil != null) setState(() => _terakhirDiganti = hasil);
  }

  String _labelTanggalDiganti() {
    final tanggal = _terakhirDiganti;
    if (tanggal == null) return 'Pilih tanggal';
    return formatTanggal(tanggal);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_jenis.wajibMasaPakai && _terakhirDiganti == null) {
      tampilSnack(context, 'Tanggal terakhir diganti wajib dipilih');
      return;
    }
    FocusScope.of(context).unfocus();

    int? masaHari;
    if (_jenis.wajibMasaPakai) {
      final n = int.parse(_masaCtrl.text);
      masaHari = _satuanBulan ? n * 30 : n;
    }

    final produk = ProdukModel(
      id: widget.produk?.id ?? '',
      namaProduk: _namaCtrl.text.trim(),
      jenis: _jenis,
      harga: _jenis.wajibHarga ? double.parse(_hargaCtrl.text) : null,
      masaPakaiHari: masaHari,
      terakhirDiganti: _jenis.wajibMasaPakai ? _terakhirDiganti : null,
      ambangStokMinimum: _jenis.punyaStok
          ? (int.tryParse(_ambangCtrl.text) ?? 5)
          : null,
    );

    setState(() => _menyimpan = true);
    try {
      if (_ubah) {
        await ApiService.ubahProduk(produk);
      } else {
        await ApiService.tambahProduk(
          produk,
          stokAwal: _jenis.punyaStok
              ? (int.tryParse(_stokAwalCtrl.text) ?? 0)
              : 0,
        );
      }
      if (!mounted) return;
      tampilSnack(
        context,
        _ubah ? 'Produk berhasil diperbarui' : 'Produk berhasil ditambahkan',
        error: false,
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Widget _angka(
    TextEditingController c,
    String label,
    String hint, {
    String? prefix,
    String? suffix,
    int minimal = 0,
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
          decoration: dekorInput(hint)
              .copyWith(prefixText: prefix, suffixText: suffix),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null) return wajib ? '$label wajib diisi' : null;
            if (n < minimal) {
              return minimal == 1
                  ? '$label harus lebih dari 0'
                  : 'Minimal $minimal';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = <Widget>[];
    void tambah(Widget x) {
      if (w.isNotEmpty) w.add(const SizedBox(height: 16));
      w.add(x);
    }

    // Jenis produk (dikunci saat ubah, karena mempengaruhi stok & transaksi)
    tambah(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelInput('Jenis Produk'),
          DropdownButtonFormField<JenisProduk>(
            value: _jenis,
            isExpanded: true,
            decoration: dekorInput('Pilih jenis')
                .copyWith(fillColor: _ubah ? WarnaMod.latar : Colors.white),
            items: [
              for (final j in JenisProduk.values)
                DropdownMenuItem(
                  value: j,
                  child: Text(j.label, style: const TextStyle(fontSize: 13)),
                ),
            ],
            onChanged: _ubah
                ? null
                : (v) {
                    if (v != null) setState(() => _jenis = v);
                  },
          ),
          if (_ubah)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Jenis produk tidak dapat diubah.',
                style: TextStyle(fontSize: 11.5, color: WarnaMod.teksRedup),
              ),
            ),
        ],
      ),
    );

    tambah(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelInput('Nama Produk'),
          TextFormField(
            controller: _namaCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: dekorInput(switch (_jenis) {
              JenisProduk.jenisAir => 'Contoh: Air RO',
              JenisProduk.galonKosong => 'Contoh: Galon Kosong',
              JenisProduk.galonKosongIsi => 'Contoh: Galon Kosong + Isi RO',
              JenisProduk.es => 'Contoh: Es Kristal',
              JenisProduk.sparepart => 'Contoh: UV Filtrasi',
            }),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nama produk wajib diisi'
                : null,
          ),
        ],
      ),
    );

    if (_jenis.wajibHarga) {
      tambah(_angka(_hargaCtrl, 'Harga', '5000', prefix: 'Rp ', minimal: 1));
    }

    if (_jenis.wajibMasaPakai) {
      tambah(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LabelInput('Masa Pakai'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _masaCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: dekorInput('Contoh: 3'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Isi masa pakai';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<bool>(
                    value: _satuanBulan,
                    decoration: dekorInput(''),
                    items: const [
                      DropdownMenuItem(
                        value: true,
                        child: Text('Bulan', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Hari', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _satuanBulan = v ?? true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      tambah(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LabelInput('Terakhir Diganti'),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pilihTanggal,
              child: InputDecorator(
                decoration: dekorInput(
                  'Pilih tanggal',
                  prefix: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: WarnaMod.teksRedup,
                  ),
                ),
                child: Text(
                  _labelTanggalDiganti(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_jenis.punyaStok) {
      tambah(
        _angka(
          _ambangCtrl,
          'Batas Stok Minimum',
          '5',
          suffix: 'pcs',
          minimal: 0,
        ),
      );
      if (!_ubah) {
        tambah(
          _angka(_stokAwalCtrl, 'Stok Awal', '0', suffix: 'pcs', minimal: 0),
        );
      }
    }

    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod(_ubah ? 'Ubah Produk' : 'Tambah Produk'),
      body: SafeArea(
        child: Center(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: w,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TombolUtama(
                      teks: _ubah ? 'Simpan Perubahan' : 'Simpan Produk',
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
