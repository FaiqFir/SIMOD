import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Menyimpan foto profil per user di direktori dokumen aplikasi.
class ProfileImageService extends ChangeNotifier {
  ProfileImageService._();
  static final ProfileImageService instance = ProfileImageService._();

  static const _storageKeyPrefix = 'profile_image_path_';
  static const _timestampKeyPrefix = 'profile_image_timestamp_';

  String? _currentUserId;
  File? _imageFile;
  String? _savedPath;
  int _imageTimestamp = 0;

  File? get imageFile => _imageFile;
  bool get hasImage => _imageFile != null;
  int get imageTimestamp => _imageTimestamp;

  /// Ganti user aktif (dipanggil setelah login/logout).
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      init();
    }
  }

  /// Muat foto profil user aktif dari path tersimpan.
  Future<void> init() async {
    if (_currentUserId == null) return;
    
    final dir = await getApplicationDocumentsDirectory();
    final storageKey = '$_storageKeyPrefix$_currentUserId';
    final timestampKey = '$_timestampKeyPrefix$_currentUserId';
    final prefsFile = File('${dir.path}/$storageKey');
    final timestampFile = File('${dir.path}/$timestampKey');
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
    if (_currentUserId == null) return;
    
    final dir = await getApplicationDocumentsDirectory();
    final storageKey = '$_storageKeyPrefix$_currentUserId';
    final timestampKey = '$_timestampKeyPrefix$_currentUserId';
    final targetPath = '${dir.path}/profile_image_$_currentUserId.jpg';
    final targetFile = await pickedFile.copy(targetPath);

    _imageFile = targetFile;
    _savedPath = targetPath;
    _imageTimestamp = DateTime.now().millisecondsSinceEpoch;

    // simpan path ke file preferensi
    final prefsFile = File('${dir.path}/$storageKey');
    await prefsFile.writeAsString(targetPath);

    // simpan timestamp
    final timestampFile = File('${dir.path}/$timestampKey');
    await timestampFile.writeAsString(_imageTimestamp.toString());

    // Hapus cache gambar lama agar FileImage dengan path yang sama tidak pakai cache lama
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    notifyListeners();
  }

  Future<void> clear() async {
    if (_currentUserId == null) return;
    
    _imageFile = null;
    _savedPath = null;
    _imageTimestamp = 0;
    final dir = await getApplicationDocumentsDirectory();
    final storageKey = '$_storageKeyPrefix$_currentUserId';
    final timestampKey = '$_timestampKeyPrefix$_currentUserId';
    final prefsFile = File('${dir.path}/$storageKey');
    final timestampFile = File('${dir.path}/$timestampKey');
    if (await prefsFile.exists()) {
      await prefsFile.delete();
    }
    if (await timestampFile.exists()) {
      await timestampFile.delete();
    }
    notifyListeners();
  }
}
