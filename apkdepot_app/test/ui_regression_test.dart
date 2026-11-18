import 'package:apkdepot_app/screens/login_screen.dart';
import 'package:apkdepot_app/widgets/date_hierarchy_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('footer versi login tetap di bawah pada layar pendek', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    const versi = 'v1.4.0 • Hak Cipta Terpelihara';
    expect(find.text(versi), findsOneWidget);
    expect(find.text('SIMOD'), findsOneWidget);

    final posisiVersi = tester.getBottomRight(find.text(versi));
    expect(posisiVersi.dy, closeTo(640, 16));
  });

  testWidgets('pemilih tanggal menampilkan urutan Tahun hingga Hari', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DateHierarchyPickerDialog(
            initialDate: null,
            firstDate: null,
            lastDate: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tahun → Bulan → Minggu → Hari'),
      findsOneWidget,
    );
    expect(find.text('1. Tahun'), findsOneWidget);
    expect(find.text('2. Bulan'), findsOneWidget);
    expect(find.text('3. Minggu'), findsOneWidget);
    expect(find.text('4. Hari'), findsOneWidget);
  });

  group('perhitungan minggu bulanan', () {
    test('Februari 2026 memiliki empat minggu', () {
      expect(weekCountForMonth(2026, 2), 4);
    });

    test('Maret 2026 memiliki lima minggu', () {
      expect(weekCountForMonth(2026, 3), 5);
    });

    test('batas awal dan akhir minggu benar', () {
      expect(weekStartForMonth(2026, 3, 2), DateTime(2026, 3, 8));
      expect(weekEndForMonth(2026, 3, 5), DateTime(2026, 3, 31));
    });
  });
}
