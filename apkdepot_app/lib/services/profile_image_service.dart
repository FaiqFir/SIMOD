import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton untuk menyimpan gambar profil terpilih dengan persistensi lokal.
/// File disalin ke direktori dokumen aplikasi dan path-nya disimpan.
class ProfileImageService extends ChangeNotifier {
  ProfileImageService._();
  static final ProfileImageService instance = ProfileImageService._();

  static const _storageKey = 'profile_image_path';
  static const _timestampKey = 'profile_image_timestamp';

  File? _imageFile;
  String? _savedPath;
  int _imageTimestamp = 0;

  File? get imageFile => _imageFile;
  bool get hasImage => _imageFile != null;
  int get imageTimestamp => _imageTimestamp;

  /// Inisialisasi: baca path tersimpan dan muat file jika ada.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefsFile = File('${dir.path}/$_storageKey');
    final timestampFile = File('${dir.path}/$_timestampKey');
    if (await prefsFile.exists()) {
      _savedPath = await prefsFile.readAsString();
      if (_savedPath != null && _savedPath!.isNotEmpty) {
        final file = File(_savedPath!);
        if (await file.exists()) {
          _imageFile = file;
          if (await timestampFile.exists()) {
            _imageTimestamp = int.parse(await timestampFile.readAsString());
          }
          notifyListeners();
        }
      }
    }
  }

  /// Pilih gambar dari galeri, salin ke storage lokal, dan simpan path-nya.
  Future<void> pickAndSaveImage() async {
    // image_picker dipakai di ProfilScreen; method ini hanya simpan File yang sudah dipilih
  }

  /// Dipanggil setelah user memilih file via image_picker.
  Future<void> setImageFromPicker(File pickedFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetPath = '${dir.path}/profile_image.jpg';
    final targetFile = await pickedFile.copy(targetPath);

    _imageFile = targetFile;
    _savedPath = targetPath;
    _imageTimestamp = DateTime.now().millisecondsSinceEpoch;

    // simpan path ke file preferensi
    final prefsFile = File('${dir.path}/$_storageKey');
    await prefsFile.writeAsString(targetPath);

    // simpan timestamp
    final timestampFile = File('${dir.path}/$_timestampKey');
    await timestampFile.writeAsString(_imageTimestamp.toString());

    // Hapus cache gambar lama agar FileImage dengan path yang sama tidak pakai cache lama
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    notifyListeners();
  }

  void clear() async {
    _imageFile = null;
    _savedPath = null;
    final dir = await getApplicationDocumentsDirectory();
    final prefsFile = File('${dir.path}/$_storageKey');
    if (await prefsFile.exists()) {
      await prefsFile.delete();
    }
    notifyListeners();
  }
}
