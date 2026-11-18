// screens/beranda_screen.dart
// Berisi 2 hal:
//   1. BerandaScreen  = kerangka utama aplikasi (bottom navbar 4 menu:
//                       Beranda, Transaksi, Produk, Laporan)
//   2. _BerandaTab    = isi halaman Beranda (hasil upgrade desain)
// Data diambil dari ApiService.beranda() (laporan.php?aksi=beranda).
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models.dart';
import 'login_screen.dart'; // WarnaMod
import 'transaksi_screen.dart';
import 'produk_screen.dart';
import 'laporan_screen.dart';
import 'profil_screen.dart';
import '../services/profile_image_service.dart';

// =====================================================================
// KERANGKA UTAMA + BOTTOM NAVBAR
// =====================================================================
class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int _tab = 0;

  // Dibunyikan tiap kali tab Beranda dibuka lagi -> data dimuat ulang
  final ValueNotifier<int> _segarkan = ValueNotifier<int>(0);
  // Aksi yang diketuk dari grid Beranda -> diteruskan ke layar Transaksi
  final ValueNotifier<JenisAksi?> _aksiDipilih = ValueNotifier<JenisAksi?>(
    null,
  );

  @override
  void dispose() {
    _segarkan.dispose();
    _aksiDipilih.dispose();
    super.dispose();
  }

  void _pindahTab(int i) {
    setState(() => _tab = i);
    if (i == 0) _segarkan.value++;
  }

  void _bukaAksi(JenisAksi aksi) {
    _aksiDipilih.value = aksi;
    _pindahTab(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      body: IndexedStack(
        index: _tab,
        children: [
          _BerandaTab(
            segarkan: _segarkan,
            onAksi: _bukaAksi,
            onPindahTab: _pindahTab,
            onBukaProfil: () => _pindahTab(4),
          ),
          TransaksiScreen(aksiDipilih: _aksiDipilih),
          const ProdukScreen(),
          const LaporanScreen(),
          ProfilScreen(onTersimpan: () => _segarkan.value++),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: WarnaMod.biru.withOpacity(0.14),
          height: 66,
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            final aktif = s.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
              color: aktif ? WarnaMod.biru : WarnaMod.teksRedup,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((s) {
            return IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected)
                  ? WarnaMod.biru
                  : WarnaMod.teksRedup,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _pindahTab,
          elevation: 8,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Transaksi',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Produk',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Laporan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// PEMBANTU TAMPILAN
// =====================================================================
/// 785000 -> "785.000"
String _rupiah(num n) {
  final negatif = n < 0;
  final s = n.abs().round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${negatif ? '-' : ''}$buf';
}

num _angka(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

/// 'HH:mm' atau 'HH:mm:ss' -> menit sejak tengah malam (null jika gagal)
int? _menit(String jam) {
  final p = jam.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String _hhmm(String jam) {
  final p = jam.split(':');
  return p.length >= 2 ? '${p[0]}:${p[1]}' : jam;
}

const Map<JenisAksi, IconData> _ikonAksi = {
  JenisAksi.isiUlang: Icons.water_drop_rounded,
  JenisAksi.beliGalonKosong: Icons.propane_tank_outlined,
  JenisAksi.galonKosongIsi: Icons.local_drink_rounded,
  JenisAksi.beliEs: Icons.ac_unit_rounded,
  JenisAksi.pinjamGalonIsi: Icons.swap_horiz_rounded,
  JenisAksi.catatPengeluaran: Icons.arrow_circle_up_rounded,
  JenisAksi.pendapatanLain: Icons.arrow_circle_down_rounded,
  JenisAksi.gantiSparepart: Icons.build_circle_outlined,
  JenisAksi.kembalikanGalon: Icons.assignment_return_outlined,
};

// =====================================================================
// ISI HALAMAN BERANDA
// =====================================================================
class _BerandaTab extends StatefulWidget {
  final ValueNotifier<int> segarkan;
  final void Function(JenisAksi) onAksi;
  final void Function(int) onPindahTab;
  final VoidCallback onBukaProfil;

  const _BerandaTab({
    required this.segarkan,
    required this.onAksi,
    required this.onPindahTab,
    required this.onBukaProfil,
  });

  @override
  State<_BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<_BerandaTab> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _memuat = true;
  String? _pengingatDiproses;

  @override
  void initState() {
    super.initState();
    widget.segarkan.addListener(_muat);
    _muat();
  }

  @override
  void dispose() {
    widget.segarkan.removeListener(_muat);
    super.dispose();
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      if (_data == null) _memuat = true;
    });
    try {
      // Minta server memeriksa stok & sparepart dulu; kalau gagal abaikan saja
      try {
        await ApiService.cekPengingat();
      } catch (_) {}
      final hasil = await ApiService.beranda();
      if (!mounted) return;
      setState(() => _data = hasil);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  // Avatar di header membuka halaman Profil lengkap.
  void _bukaProfil() {
    widget.onBukaProfil();
  }

  @override
  Widget build(BuildContext context) {
    final depot = ApiService.depot;
    final lebar = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: _muat,
      color: WarnaMod.biru,
      edgeOffset: 120,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ---------------- HEADER ----------------
          SliverToBoxAdapter(child: _header(depot)),

          // ---------------- ISI ----------------
          if (_memuat && _data == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: WarnaMod.biru),
              ),
            )
          else if (_data == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: _tampilanError()),
            )
          else
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: lebar > 600 ? 600 : lebar,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 58),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kartuOmset(_data!),
                        const SizedBox(height: 20),
                        _judul('Stok & Aset', ruangAtas: 0),
                        _ringkasanStok(_data!),
                        const SizedBox(height: 22),
                        _judul('Aksi Cepat'),
                        _gridAksi(),
                        const SizedBox(height: 22),
                        _judul('Pengingat Stok dan Sparepart'),
                        _daftarPengingat(_data!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _header(DepotModel? depot) {
    final sekarang = TimeOfDay.now();
    final menitSekarang = sekarang.hour * 60 + sekarang.minute;
    final buka = depot == null ? null : _menit(depot.jamBuka);
    final tutup = depot == null ? null : _menit(depot.jamTutup);
    bool? sedangBuka;
    if (buka != null && tutup != null) {
      sedangBuka = tutup > buka
          ? (menitSekarang >= buka && menitSekarang < tutup)
          : (menitSekarang >= buka ||
                menitSekarang < tutup); // lewat tengah malam
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Hiasan tetesan air tetap utuh di dalam banner.
          Positioned(
            right: 16,
            bottom: 16,
            child: Icon(
              Icons.water_drop_rounded,
              size: 72,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${ApiService.pengguna?.namaPengelola ?? 'Pengelola'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          depot?.namaDepot ?? 'Depot',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _bukaProfil,
                    customBorder: const CircleBorder(),
                    child: AnimatedBuilder(
                      animation: ProfileImageService.instance,
                      builder: (context, _) {
                        final img = ProfileImageService.instance.imageFile;
                        final inisial =
                            (ApiService.pengguna?.namaPengelola ?? 'P')
                                .trim()
                                .split(RegExp(r'\s+'))
                                .where((e) => e.isNotEmpty)
                                .take(2)
                                .map((e) => e[0].toUpperCase())
                                .join();
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          key: ProfileImageService.instance.hasImage
                              ? ValueKey(ProfileImageService.instance.imageTimestamp)
                              : null,
                          backgroundImage: img != null ? FileImage(img) : null,
                          child: img == null
                              ? Text(
                                  inisial,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      depot?.alamat ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    depot == null
                        ? '-'
                        : '${_hhmm(depot.jamBuka)} - ${_hhmm(depot.jamTutup)}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  if (sedangBuka != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sedangBuka
                            ? const Color(0xFF2E7D32)
                            : Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sedangBuka ? 'Buka' : 'Tutup',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _kartuOmset(Map<String, dynamic> d) {
    final masuk = _angka(d['pemasukan_hari_ini']);
    final keluar = _angka(d['pengeluaran_hari_ini']);
    final selisih = masuk - keluar;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        boxShadow: [
          BoxShadow(
            color: WarnaMod.biru.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Omset Hari Ini',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Hari ini',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 5, right: 6),
                child: Text(
                  'Rp',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _rupiah(masuk),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _mini(Icons.south_west_rounded, 'Pemasukan', masuk),
                _pemisah(),
                _mini(Icons.north_east_rounded, 'Pengeluaran', keluar),
                _pemisah(),
                _mini(
                  Icons.account_balance_wallet_outlined,
                  'Selisih',
                  selisih,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pemisah() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white.withOpacity(0.3),
  );

  Widget _mini(IconData ikon, String label, num nilai) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 11, color: Colors.white.withOpacity(0.85)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rupiah(nilai),
              style: const TextStyle(
                fontSize: 13,
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
  Widget _judul(String teks, {double ruangAtas = 0}) {
    return Padding(
      padding: EdgeInsets.only(top: ruangAtas, bottom: 10),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: WarnaMod.teks,
        ),
      ),
    );
  }

  Widget _ringkasanStok(Map<String, dynamic> d) {
    return Row(
      children: [
        _kartuStok(
          ikon: Icons.ac_unit_rounded,
          warna: const Color(0xFF00ACC1),
          label: 'Stok Es',
          nilai: _angka(d['stok_es']).toInt(),
          satuan: 'Pack',
        ),
        const SizedBox(width: 10),
        _kartuStok(
          ikon: Icons.propane_tank_outlined,
          warna: WarnaMod.biru,
          label: 'Galon Kosong',
          nilai: _angka(d['stok_galon_kosong']).toInt(),
          satuan: 'Pcs',
        ),
        const SizedBox(width: 10),
        _kartuStok(
          ikon: Icons.swap_horiz_rounded,
          warna: const Color(0xFFF59E0B),
          label: 'Galon Dipinjam',
          nilai: _angka(d['galon_dipinjam']).toInt(),
          satuan: 'Pcs',
        ),
      ],
    );
  }

  Widget _kartuStok({
    required IconData ikon,
    required Color warna,
    required String label,
    required int nilai,
    required String satuan,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: warna.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(ikon, size: 17, color: warna),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: WarnaMod.teksRedup),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$nilai',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: WarnaMod.teks,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  satuan,
                  style: const TextStyle(
                    fontSize: 11,
                    color: WarnaMod.teksRedup,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _gridAksi() {
    final aksi = JenisAksi.values;
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
            onTap: () => widget.onAksi(a),
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
                    child: Icon(_ikonAksi[a], size: 21, color: WarnaMod.biru),
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

  // ------------------------------------------------------------------
  // Konfirmasi status selesai -> simpan di server -> tampilkan popup sukses.
  // ------------------------------------------------------------------
  Future<void> _konfirmasiSelesai(Map<String, dynamic> pengingat) async {
    final id = pengingat['id']?.toString() ?? '';
    final nama = (pengingat['nama_produk'] ?? 'Tugas ini').toString();
    if (id.isEmpty || _pengingatDiproses != null) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Konfirmasi Selesai?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tandai "$nama" sebagai selesai? Status baru berubah setelah Anda mengonfirmasi.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Belum'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _pengingatDiproses = id);
    try {
      await ApiService.ubahStatusPengingat(id, 'selesai');
      if (!mounted) return;

      final dataBaru = Map<String, dynamic>.from(_data!);
      final daftar = dataBaru['pengingat'];
      if (daftar is List) {
        dataBaru['pengingat'] = daftar
            .where((item) => item is! Map || item['id']?.toString() != id)
            .toList();
      }
      setState(() => _data = dataBaru);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 58,
                color: Color(0xFF2E9E5B),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tugas Selesai',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: WarnaMod.teks,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"$nama" telah ditandai selesai.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: WarnaMod.teksRedup,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _pengingatDiproses = null);
    }
  }

  // ------------------------------------------------------------------
  Widget _daftarPengingat(Map<String, dynamic> d) {
    final raw = d['pengingat'];
    final list = raw is List ? raw : const [];

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 34,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 8),
            const Text(
              'Semua aman',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tidak ada stok menipis atau sparepart yang perlu diganti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: WarnaMod.teksRedup),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final item in list)
          _itemPengingat(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  Widget _itemPengingat(Map<String, dynamic> p) {
    final stokMenipis = p['jenis']?.toString() == 'stok_menipis';
    final warna = stokMenipis ? WarnaMod.error : const Color(0xFFF59E0B);
    final nama = (p['nama_produk'] ?? '-').toString();
    final pesan = (p['pesan'] ?? '').toString();
    final id = p['id']?.toString() ?? '';
    final status = p['status']?.toString() ?? 'belum_dibaca';
    final statusLabel = switch (status) {
      'dibaca' => 'Diproses',
      'selesai' => 'Selesai',
      _ => 'Belum Ditangani',
    };
    final statusWarna = switch (status) {
      'dibaca' => WarnaMod.biru,
      'selesai' => const Color(0xFF2E9E5B),
      _ => const Color(0xFFF59E0B),
    };
    final sedangDiproses = _pengingatDiproses == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          // stok menipis -> ke Produk; sparepart -> ke Transaksi (Ganti Sparepart)
          onTap: () {
            if (stokMenipis) {
              widget.onPindahTab(2);
            } else {
              widget.onAksi(JenisAksi.gantiSparepart);
            }
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: warna),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: warna.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            stokMenipis
                                ? Icons.inventory_2_outlined
                                : Icons.build_circle_outlined,
                            size: 19,
                            color: warna,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: WarnaMod.teks,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pesan,
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
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusWarna.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusWarna,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            TextButton(
                              onPressed: sedangDiproses
                                  ? null
                                  : () => _konfirmasiSelesai(p),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                              ),
                              child: sedangDiproses
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Selesaikan',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
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

  // ------------------------------------------------------------------
  Widget _tampilanError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: WarnaMod.teksRedup,
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Gagal memuat data',
            textAlign: TextAlign.center,
            style: const TextStyle(color: WarnaMod.teksRedup),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _muat,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
