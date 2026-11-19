import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../services/profile_image_service.dart';
import 'login_screen.dart';

class ProfilScreen extends StatefulWidget {
  final VoidCallback? onTersimpan;

  const ProfilScreen({super.key, this.onTersimpan});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaPengelolaCtrl;
  late final TextEditingController _namaDepotCtrl;
  late final TextEditingController _alamatCtrl;

  TimeOfDay? _jamBuka;
  TimeOfDay? _jamTutup;
  bool _notifikasiStok = true;
  bool _notifikasiSparepart = true;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    final pengguna = ApiService.pengguna;
    final depot = ApiService.depot;
    _namaPengelolaCtrl = TextEditingController(
      text: pengguna?.namaPengelola ?? '',
    );
    _namaDepotCtrl = TextEditingController(text: depot?.namaDepot ?? '');
    _alamatCtrl = TextEditingController(text: depot?.alamat ?? '');
    _jamBuka = _waktuDariString(depot?.jamBuka);
    _jamTutup = _waktuDariString(depot?.jamTutup);
    _notifikasiStok = depot?.notifikasiStokMenipis ?? true;
    _notifikasiSparepart = depot?.notifikasiSparepart ?? true;

    // Listen to profile image changes from service
    ProfileImageService.instance.addListener(_onProfileImageChanged);
  }

  @override
  void dispose() {
    _namaPengelolaCtrl.dispose();
    _namaDepotCtrl.dispose();
    _alamatCtrl.dispose();
    ProfileImageService.instance.removeListener(_onProfileImageChanged);
    super.dispose();
  }

  void _onProfileImageChanged() {
    if (mounted) setState(() {});
  }

  

  TimeOfDay? _waktuDariString(String? nilai) {
    if (nilai == null) return null;
    final bagian = nilai.split(':');
    if (bagian.length < 2) return null;
    final jam = int.tryParse(bagian[0]);
    final menit = int.tryParse(bagian[1]);
    if (jam == null || menit == null) return null;
    return TimeOfDay(hour: jam, minute: menit);
  }

  String _formatWaktu(TimeOfDay waktu) {
    return '${waktu.hour.toString().padLeft(2, '0')}:'
        '${waktu.minute.toString().padLeft(2, '0')}';
  }

  String get _inisial {
    final bagian = _namaPengelolaCtrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (bagian.isEmpty) return 'P';
    return bagian.take(2).map((item) => item[0].toUpperCase()).join();
  }

  Future<void> _pilihFotoProfil() async {
    final picker = ImagePicker();
    final hasil = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (hasil != null && mounted) {
      final file = File(hasil.path);
      await ProfileImageService.instance.setImageFromPicker(file);
      // setState is called via listener
    }
  }

  Future<void> _hapusFotoProfil() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Foto Profil?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Foto profil akan dihapus dan kembali ke inisial nama.',
          style: TextStyle(fontSize: 13),
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
    if (yakin != true || !mounted) return;

    await ProfileImageService.instance.clear();
    // setState dipanggil via listener
    if (mounted) tampilSnack(context, 'Foto profil dihapus', error: false);
  }

  Future<void> _editTeks({
    required String judul,
    required TextEditingController controller,
    required String hint,
    bool banyakBaris = false,
  }) async {
    final sementara = TextEditingController(text: controller.text);
    final hasil = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          judul,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: sementara,
          autofocus: true,
          maxLines: banyakBaris ? 3 : 1,
          textCapitalization: TextCapitalization.words,
          decoration: dekorInput(hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final nilai = sementara.text.trim();
              if (nilai.isEmpty) {
                tampilSnack(context, '$judul wajib diisi');
                return;
              }
              Navigator.pop(dialogContext, nilai);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final nilai = hasil;
    sementara.dispose();
    if (nilai != null && mounted) {
      setState(() => controller.text = nilai);
    }
  }

  Future<void> _editJamOperasional() async {
    final hasil = await showDialog<List<TimeOfDay>>(
      context: context,
      builder: (dialogContext) => _DialogJamOperasional(
        jamBuka: _jamBuka ?? const TimeOfDay(hour: 8, minute: 0),
        jamTutup: _jamTutup ?? const TimeOfDay(hour: 21, minute: 0),
      ),
    );
    if (hasil != null && mounted) {
      setState(() {
        _jamBuka = hasil[0];
        _jamTutup = hasil[1];
      });
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    final nama = _namaPengelolaCtrl.text.trim();
    final namaDepot = _namaDepotCtrl.text.trim();
    final alamat = _alamatCtrl.text.trim();
    final jamBuka = _jamBuka;
    final jamTutup = _jamTutup;

    if (nama.isEmpty || namaDepot.isEmpty || alamat.isEmpty) {
      tampilSnack(context, 'Semua data profil wajib diisi');
      return;
    }
    if (jamBuka == null || jamTutup == null) {
      tampilSnack(context, 'Jam buka dan jam tutup wajib dipilih');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _menyimpan = true);
    try {
      final depot = ApiService.depot;
      if (depot == null) {
        throw ApiException('Data depot tidak ditemukan. Silakan login ulang.');
      }
      await ApiService.ubahProfil(
        namaPengelola: nama,
        depotBaru: depot.copyWith(
          namaDepot: namaDepot,
          alamat: alamat,
          jamBuka: _formatWaktu(jamBuka),
          jamTutup: _formatWaktu(jamTutup),
          notifikasiStokMenipis: _notifikasiStok,
          notifikasiSparepart: _notifikasiSparepart,
        ),
      );
      if (!mounted) return;
      widget.onTersimpan?.call();
      tampilSnack(context, 'Perubahan profil berhasil disimpan', error: false);
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _keluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Keluar Akun?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Anda harus memasukkan kembali nama pengguna dan kata sandi untuk masuk lagi.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: WarnaMod.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    ApiService.keluar();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _barisProfil({
    required String label,
    required String nilai,
    required VoidCallback onEdit,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WarnaMod.garis.withOpacity(0.75)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: WarnaMod.teksRedup,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nilai.isEmpty ? 'Belum diisi' : nilai,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WarnaMod.teks,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.edit_outlined, size: 18, color: WarnaMod.biru),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barisPengaturan({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WarnaMod.garis.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WarnaMod.teks,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: WarnaMod.biru,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pengguna = ApiService.pengguna;
    final depot = ApiService.depot;
    final jamBuka = _jamBuka;
    final jamTutup = _jamTutup;

    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: appBarMod('Profil Pengelola'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pilihFotoProfil,
                        onLongPress: ProfileImageService.instance.hasImage
                            ? _hapusFotoProfil
                            : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: WarnaMod.biru,
                              key: ProfileImageService.instance.hasImage
                                  ? ValueKey(ProfileImageService.instance.imageTimestamp)
                                  : null,
                              backgroundImage: ProfileImageService.instance.imageFile != null
                                  ? FileImage(ProfileImageService.instance.imageFile!)
                                  : null,
                              child: ProfileImageService.instance.imageFile == null
                                  ? Text(
                                      _inisial,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: WarnaMod.biru,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: WarnaMod.biru.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            if (ProfileImageService.instance.hasImage)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _hapusFotoProfil,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: WarnaMod.error,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: WarnaMod.error.withOpacity(0.35),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.delete_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pengguna?.namaPengelola ?? 'Pengelola',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: WarnaMod.teks,
                      ),
                    ),
                    Text(
                      depot?.namaDepot ?? 'Depot Air',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: WarnaMod.teksRedup,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _barisProfil(
                      label: 'Nama Pengelola',
                      nilai: _namaPengelolaCtrl.text,
                      onEdit: () => _editTeks(
                        judul: 'Nama Pengelola',
                        controller: _namaPengelolaCtrl,
                        hint: 'Nama lengkap pengelola',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _barisProfil(
                      label: 'Nama Depot',
                      nilai: _namaDepotCtrl.text,
                      onEdit: () => _editTeks(
                        judul: 'Nama Depot',
                        controller: _namaDepotCtrl,
                        hint: 'Nama depot air',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _barisProfil(
                      label: 'Alamat Depot',
                      nilai: _alamatCtrl.text,
                      onEdit: () => _editTeks(
                        judul: 'Alamat Depot',
                        controller: _alamatCtrl,
                        hint: 'Alamat lengkap depot',
                        banyakBaris: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _barisProfil(
                      label: 'Jam Operasional',
                      nilai: jamBuka == null || jamTutup == null
                          ? 'Belum diatur'
                          : '${_formatWaktu(jamBuka)} - ${_formatWaktu(jamTutup)}',
                      onEdit: _editJamOperasional,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Pengaturan',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: WarnaMod.teks,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _barisPengaturan(
                      label: 'Notifikasi Stok Menipis',
                      value: _notifikasiStok,
                      onChanged: (value) =>
                          setState(() => _notifikasiStok = value),
                    ),
                    const SizedBox(height: 8),
                    _barisPengaturan(
                      label: 'Notifikasi Sparepart',
                      value: _notifikasiSparepart,
                      onChanged: (value) =>
                          setState(() => _notifikasiSparepart = value),
                    ),
                    const SizedBox(height: 18),
                    TombolUtama(
                      teks: 'Simpan Perubahan',
                      memuat: _menyimpan,
                      onTekan: _simpan,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _menyimpan ? null : _keluar,
                        child: const Text(
                          'Keluar Akun',
                          style: TextStyle(
                            color: WarnaMod.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

class _DialogJamOperasional extends StatefulWidget {
  final TimeOfDay jamBuka;
  final TimeOfDay jamTutup;

  const _DialogJamOperasional({required this.jamBuka, required this.jamTutup});

  @override
  State<_DialogJamOperasional> createState() => _DialogJamOperasionalState();
}

class _DialogJamOperasionalState extends State<_DialogJamOperasional> {
  late TimeOfDay _jamBuka;
  late TimeOfDay _jamTutup;

  @override
  void initState() {
    super.initState();
    _jamBuka = widget.jamBuka;
    _jamTutup = widget.jamTutup;
  }

  String _format(TimeOfDay waktu) {
    return '${waktu.hour.toString().padLeft(2, '0')}:'
        '${waktu.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pilih(bool buka) async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: buka ? _jamBuka : _jamTutup,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hasil == null) return;
    setState(() {
      if (buka) {
        _jamBuka = hasil;
      } else {
        _jamTutup = hasil;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Jam Operasional',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pilih(true),
            child: InputDecorator(
              decoration: dekorInput(
                'Jam Buka',
                prefix: const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: WarnaMod.teksRedup,
                ),
              ),
              child: Text(
                _format(_jamBuka),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pilih(false),
            child: InputDecorator(
              decoration: dekorInput(
                'Jam Tutup',
                prefix: const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: WarnaMod.teksRedup,
                ),
              ),
              child: Text(
                _format(_jamTutup),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [_jamBuka, _jamTutup]),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
