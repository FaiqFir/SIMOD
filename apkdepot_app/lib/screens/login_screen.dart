// Login + Registrasi (dua kelas dalam satu file).
// Layar hanya mengurus tampilan; data lewat ApiService.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import 'beranda_screen.dart';

// Warna & gaya bersama.
class WarnaMod {
  static const Color biru = Color(0xFF2196F3);
  static const Color biruTua = Color(0xFF0D47A1);
  static const Color biruGelap = Color(0xFF1565C0);
  static const Color latar = Color(0xFFF4F6F7);
  static const Color garis = Color(0xFFCFE0F1);
  static const Color teks = Color(0xFF1B2733);
  static const Color teksRedup = Color(0xFF6B7A89);
  static const Color error = Color(0xFFD32F2F);

  static const LinearGradient header = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
  );
}

// Tombol biru utama: gelap saat ditekan/di-hover.
class TombolUtama extends StatelessWidget {
  final String teks;
  final bool memuat;
  final VoidCallback? onTekan;

  const TombolUtama({
    super.key,
    required this.teks,
    required this.onTekan,
    this.memuat = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: memuat ? null : onTekan,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return WarnaMod.biru.withOpacity(0.6);
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return WarnaMod.biruTua;
            }
            return WarnaMod.biru;
          }),
        ),
        child: memuat
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                teks,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// Label tebal di atas kolom isian.
class LabelInput extends StatelessWidget {
  final String teks;
  const LabelInput(this.teks);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: WarnaMod.teks,
        ),
      ),
    );
  }
}

InputDecoration dekorInput(String hint, {Widget? suffix, Widget? prefix}) {
  OutlineInputBorder garis(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9AA8B6)),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    prefixIcon: prefix,
    enabledBorder: garis(WarnaMod.garis),
    focusedBorder: garis(WarnaMod.biru),
    errorBorder: garis(WarnaMod.error),
    focusedErrorBorder: garis(WarnaMod.error),
  );
}

void tampilSnack(BuildContext context, String pesan, {bool error = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: error ? WarnaMod.error : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

// LOGIN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _sandiCtrl = TextEditingController();
  bool _sembunyikan = true;
  bool _memuat = false;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _sandiCtrl.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _memuat = true);
    try {
      await ApiService.masuk(_namaCtrl.text.trim(), _sandiCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BerandaScreen()),
      );
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  void _keRegistrasi() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegistrasiScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Logo
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                          ),
                        ),
                        child: const Icon(
                          Icons.water_drop_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'SIMOD',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: WarnaMod.biru,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Sistem Manajemen Operasional Depot Air Minum',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: WarnaMod.teksRedup,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Nama pengguna
                    const LabelInput('Nama Pengguna'),
                    TextFormField(
                      controller: _namaCtrl,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: dekorInput('Masukkan Nama'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama pengguna wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Kata sandi
                    const LabelInput('Kata Sandi'),
                    TextFormField(
                      controller: _sandiCtrl,
                      obscureText: _sembunyikan,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _masuk(),
                      decoration: dekorInput(
                        'Masukkan kata sandi',
                        suffix: IconButton(
                          icon: Icon(
                            _sembunyikan
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: WarnaMod.teksRedup,
                          ),
                          onPressed: () =>
                              setState(() => _sembunyikan = !_sembunyikan),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Kata sandi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    TombolUtama(
                      teks: 'Masuk ke Aplikasi',
                      memuat: _memuat,
                      onTekan: _masuk,
                    ),
                    const SizedBox(height: 28),

                    Center(
                      child: TextButton(
                        onPressed: _memuat ? null : _keRegistrasi,
                        child: const Text(
                          'Belum punya akun? Daftar di sini',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WarnaMod.biru,
                            decoration: TextDecoration.underline,
                            decorationColor: WarnaMod.biru,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'v1.4.0 • Hak Cipta Terpelihara',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: WarnaMod.teksRedup),
          ),
        ),
      ),
    );
  }
}

// REGISTRASI AKUN BARU (Data Akun Pengelola + Data Depot Air)
class RegistrasiScreen extends StatefulWidget {
  const RegistrasiScreen({super.key});

  @override
  State<RegistrasiScreen> createState() => _RegistrasiScreenState();
}

class _RegistrasiScreenState extends State<RegistrasiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pengelolaCtrl = TextEditingController();
  final _penggunaCtrl = TextEditingController();
  final _sandiCtrl = TextEditingController();
  final _depotCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  TimeOfDay? _buka;
  TimeOfDay? _tutup;
  bool _sembunyikan = true;
  bool _memuat = false;

  @override
  void dispose() {
    _pengelolaCtrl.dispose();
    _penggunaCtrl.dispose();
    _sandiCtrl.dispose();
    _depotCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  // Format 'HH:mm' sesuai kolom TIME di database
  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pilihJam(bool buka) async {
    final hasil = await showTimePicker(
      context: context,
      initialTime:
          (buka ? _buka : _tutup) ?? TimeOfDay(hour: buka ? 8 : 17, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hasil != null) {
      setState(() {
        if (buka) {
          _buka = hasil;
        } else {
          _tutup = hasil;
        }
      });
    }
  }

  Future<void> _daftar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_buka == null || _tutup == null) {
      tampilSnack(context, 'Jam buka dan jam tutup wajib dipilih');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _memuat = true);
    try {
      await ApiService.daftar(
        namaPengguna: _penggunaCtrl.text.trim(),
        kataSandi: _sandiCtrl.text,
        namaPengelola: _pengelolaCtrl.text.trim(),
        namaDepot: _depotCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        jamBuka: _fmt(_buka!),
        jamTutup: _fmt(_tutup!),
      );
      if (!mounted) return;
      // Setelah daftar, ApiService sudah menyimpan login -> langsung ke Beranda
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BerandaScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) tampilSnack(context, e.pesan);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Widget _judulBagian(String teks) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Text(
      teks,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: WarnaMod.biru,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _kolomJam(String label, TimeOfDay? nilai, bool buka) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabelInput(label),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pilihJam(buka),
            child: InputDecorator(
              decoration: dekorInput(
                '00:00',
                prefix: const Icon(
                  Icons.access_time,
                  size: 18,
                  color: WarnaMod.teksRedup,
                ),
              ),
              child: Text(
                nilai == null ? '00:00' : _fmt(nilai),
                style: TextStyle(
                  fontSize: 13,
                  color: nilai == null
                      ? const Color(0xFF9AA8B6)
                      : WarnaMod.teks,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _wajib(String? v, String nama) =>
      (v == null || v.trim().isEmpty) ? '$nama wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Registrasi Akun Baru',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: WarnaMod.header),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _judulBagian('DATA AKUN PENGELOLA'),
                    const LabelInput('Nama Pengelola'),
                    TextFormField(
                      controller: _pengelolaCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: dekorInput('Contoh: Joko Wijaya'),
                      validator: (v) => _wajib(v, 'Nama pengelola'),
                    ),
                    const SizedBox(height: 14),
                    const LabelInput('Nama Pengguna'),
                    TextFormField(
                      controller: _penggunaCtrl,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: dekorInput('Contoh: Solowili567'),
                      validator: (v) => _wajib(v, 'Nama pengguna'),
                    ),
                    const SizedBox(height: 14),
                    const LabelInput('Kata Sandi'),
                    TextFormField(
                      controller: _sandiCtrl,
                      obscureText: _sembunyikan,
                      textInputAction: TextInputAction.next,
                      decoration: dekorInput(
                        'Minimal 6 karakter',
                        suffix: IconButton(
                          icon: Icon(
                            _sembunyikan
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: WarnaMod.teksRedup,
                          ),
                          onPressed: () =>
                              setState(() => _sembunyikan = !_sembunyikan),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Kata sandi wajib diisi';
                        }
                        if (v.length < 6) return 'Minimal 6 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    _judulBagian('DATA DEPOT AIR'),
                    const LabelInput('Nama Depot Air'),
                    TextFormField(
                      controller: _depotCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: dekorInput('Contoh: Depot Air Nusantara'),
                      validator: (v) => _wajib(v, 'Nama depot'),
                    ),
                    const SizedBox(height: 14),
                    const LabelInput('Alamat Depot'),
                    TextFormField(
                      controller: _alamatCtrl,
                      minLines: 3,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: dekorInput('Alamat lengkap lokasi depot air'),
                      validator: (v) => _wajib(v, 'Alamat depot'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kolomJam('Jam Buka', _buka, true),
                        const SizedBox(width: 12),
                        _kolomJam('Jam Tutup', _tutup, false),
                      ],
                    ),
                    const SizedBox(height: 32),

                    TombolUtama(
                      teks: 'Daftar Akun',
                      memuat: _memuat,
                      onTekan: _daftar,
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

// AppBar biru bergradasi — dipakai semua layar.
// Tombol kembali otomatis kalau dibuka lewat Navigator.push.
PreferredSizeWidget appBarMod(String judul, {List<Widget>? aksi}) {
  return AppBar(
    elevation: 0,
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    title: Text(
      judul,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    actions: aksi,
    flexibleSpace: Container(
      decoration: const BoxDecoration(gradient: WarnaMod.header),
    ),
  );
}
