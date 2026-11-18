import 'package:flutter/material.dart';

const List<String> _namaBulan = [
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

const List<String> _namaHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// Jumlah minggu dalam bulan dengan pembagian 1–7, 8–14, dan seterusnya.
int weekCountForMonth(int year, int month) {
  final jumlahHari = DateTime(year, month + 1, 0).day;
  return (jumlahHari + 6) ~/ 7;
}

/// Tanggal pertama pada minggu tertentu di dalam bulan.
DateTime weekStartForMonth(int year, int month, int week) {
  return DateTime(year, month, (week - 1) * 7 + 1);
}

/// Tanggal terakhir pada minggu tertentu di dalam bulan.
DateTime weekEndForMonth(int year, int month, int week) {
  final jumlahHari = DateTime(year, month + 1, 0).day;
  final akhir = week * 7;
  return DateTime(year, month, akhir > jumlahHari ? jumlahHari : akhir);
}

/// Tampilkan dialog pemilih tanggal bertingkat dan kembalikan tanggal terpilih.
Future<DateTime?> showDateHierarchyPicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => DateHierarchyPickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class DateHierarchyPickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DateHierarchyPickerDialog({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
  });

  @override
  State<DateHierarchyPickerDialog> createState() =>
      _DateHierarchyPickerDialogState();
}

class _DateHierarchyPickerDialogState extends State<DateHierarchyPickerDialog> {
  late final DateTime _tanggalAwal;
  late final DateTime _tanggalAkhir;
  late int _tahun;
  late int _bulan;
  late int _minggu;
  late int _hari;

  @override
  void initState() {
    super.initState();
    final sekarang = DateTime.now();
    _tanggalAwal = _tanpaJam(widget.firstDate ?? DateTime(2020));
    _tanggalAkhir = _tanpaJam(widget.lastDate ?? sekarang);
    final awal = _tanpaJam(widget.initialDate ?? sekarang);
    _tahun = awal.year.clamp(_tanggalAwal.year, _tanggalAkhir.year);
    _bulan = awal.month;
    _minggu = ((awal.day - 1) ~/ 7) + 1;
    _hari = awal.day;
    _normalisasiMinggu();
  }

  DateTime _tanpaJam(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sesudahAkhir(DateTime value) => value.isAfter(_tanggalAkhir);

  bool _sebelumAwal(DateTime value) => value.isBefore(_tanggalAwal);

  List<DateTime> _hariDalamMinggu() {
    final mulai = weekStartForMonth(_tahun, _bulan, _minggu);
    final akhir = weekEndForMonth(_tahun, _bulan, _minggu);
    final hasil = <DateTime>[];
    for (
      var tanggal = mulai;
      !tanggal.isAfter(akhir);
      tanggal = tanggal.add(const Duration(days: 1))
    ) {
      if (!_sebelumAwal(tanggal) && !_sesudahAkhir(tanggal)) {
        hasil.add(tanggal);
      }
    }
    return hasil;
  }

  void _normalisasiMinggu() {
    final jumlahMinggu = weekCountForMonth(_tahun, _bulan);
    _minggu = _minggu.clamp(1, jumlahMinggu);

    final hariValid = _hariDalamMinggu();
    if (hariValid.isEmpty) {
      _hari = 1;
      return;
    }

    final adaHariTerpilih = hariValid.any((tanggal) => tanggal.day == _hari);
    if (!adaHariTerpilih) {
      _hari = hariValid.first.day;
    }
  }

  void _ubahTahun(int? tahun) {
    if (tahun == null) return;
    setState(() {
      _tahun = tahun;
      _bulan = _bulan.clamp(
        1,
        tahun == _tanggalAkhir.year ? _tanggalAkhir.month : 12,
      );
      _minggu = 1;
      _hari = 1;
      _normalisasiMinggu();
    });
  }

  void _ubahBulan(int? bulan) {
    if (bulan == null) return;
    setState(() {
      _bulan = bulan;
      _minggu = 1;
      _hari = 1;
      _normalisasiMinggu();
    });
  }

  void _ubahMinggu(int? minggu) {
    if (minggu == null) return;
    setState(() {
      _minggu = minggu;
      _hari = 1;
      _normalisasiMinggu();
    });
  }

  void _ubahHari(int? hari) {
    if (hari == null) return;
    setState(() => _hari = hari);
  }

  List<int> _tahunTersedia() {
    return [
      for (var tahun = _tanggalAwal.year; tahun <= _tanggalAkhir.year; tahun++)
        tahun,
    ];
  }

  List<int> _bulanTersedia() {
    final maksimum = _tahun == _tanggalAkhir.year ? _tanggalAkhir.month : 12;
    return [for (var bulan = 1; bulan <= maksimum; bulan++) bulan];
  }

  List<int> _mingguTersedia() {
    return [
      for (
        var minggu = 1;
        minggu <= weekCountForMonth(_tahun, _bulan);
        minggu++
      )
        minggu,
    ];
  }

  List<int> _hariTersedia() {
    return _hariDalamMinggu().map((tanggal) => tanggal.day).toList();
  }

  String _labelMinggu(int minggu) {
    final mulai = weekStartForMonth(_tahun, _bulan, minggu);
    final akhir = weekEndForMonth(_tahun, _bulan, minggu);
    return 'Minggu $minggu (${mulai.day}–${akhir.day} ${_namaBulan[_bulan - 1].substring(0, 3)})';
  }

  String _labelHari(int hari) {
    final tanggal = DateTime(_tahun, _bulan, hari);
    return '${_namaHari[tanggal.weekday - 1]}, $hari ${_namaBulan[_bulan - 1]}';
  }

  InputDecoration _dekorasi(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF6B7A89),
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCFE0F1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCFE0F1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required int value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
    required String Function(int) itemLabel,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        items: [
          for (final item in items)
            DropdownMenuItem(
              value: item,
              child: Text(
                itemLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hariTersedia = _hariTersedia();
    final tanggalTerpilih = DateTime(_tahun, _bulan, _hari);

    return AlertDialog(
      title: const Text(
        'Pilih Tanggal',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 18,
                      color: Color(0xFF2196F3),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Urutan pilihan: Tahun → Bulan → Minggu → Hari',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2733),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: _dekorasi('1. Tahun'),
                child: _dropdown(
                  label: 'Tahun',
                  value: _tahun,
                  items: _tahunTersedia(),
                  onChanged: _ubahTahun,
                  itemLabel: (tahun) => '$tahun',
                ),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: _dekorasi('2. Bulan'),
                child: _dropdown(
                  label: 'Bulan',
                  value: _bulan,
                  items: _bulanTersedia(),
                  onChanged: _ubahBulan,
                  itemLabel: (bulan) => _namaBulan[bulan - 1],
                ),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: _dekorasi('3. Minggu'),
                child: _dropdown(
                  label: 'Minggu',
                  value: _minggu,
                  items: _mingguTersedia(),
                  onChanged: _ubahMinggu,
                  itemLabel: _labelMinggu,
                ),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: _dekorasi('4. Hari'),
                child: hariTersedia.isEmpty
                    ? const Text(
                        'Tidak ada hari yang dapat dipilih',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9AA8B6),
                        ),
                      )
                    : _dropdown(
                        label: 'Hari',
                        value: _hari,
                        items: hariTersedia,
                        onChanged: _ubahHari,
                        itemLabel: _labelHari,
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                'Dipilih: ${_labelHari(_hari)}, ${tanggalTerpilih.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: hariTersedia.isEmpty
              ? null
              : () => Navigator.pop(context, tanggalTerpilih),
          child: const Text('Simpan Tanggal'),
        ),
      ],
    );
  }
}
