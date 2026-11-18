import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper aman untuk menyimpan token/credential login.
/// Menggunakan flutter_secure_storage (encrypted di Android Keystore / iOS Keychain).
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyDepotId = 'depot_id';
  static const _keyPenggunaId = 'pengguna_id';
  static const _keyNamaPengguna = 'nama_pengguna';
  static const _keyNamaPengelola = 'nama_pengelola';

  /// Simpan data sesi login.
  Future<void> saveSession({
    required String depotId,
    required String penggunaId,
    required String namaPengguna,
    required String namaPengelola,
  }) async {
    await _storage.write(key: _keyDepotId, value: depotId);
    await _storage.write(key: _keyPenggunaId, value: penggunaId);
    await _storage.write(key: _keyNamaPengguna, value: namaPengguna);
    await _storage.write(key: _keyNamaPengelola, value: namaPengelola);
  }

  /// Baca data sesi yang tersimpan.
  Future<SavedSession?> readSession() async {
    final depotId = await _storage.read(key: _keyDepotId);
    final penggunaId = await _storage.read(key: _keyPenggunaId);
    final namaPengguna = await _storage.read(key: _keyNamaPengguna);
    final namaPengelola = await _storage.read(key: _keyNamaPengelola);

    if (depotId == null ||
        penggunaId == null ||
        namaPengguna == null ||
        namaPengelola == null) {
      return null;
    }
    return SavedSession(
      depotId: depotId,
      penggunaId: penggunaId,
      namaPengguna: namaPengguna,
      namaPengelola: namaPengelola,
    );
  }

  /// Hapus semua data sesi (logout).
  Future<void> clearSession() async {
    await _storage.delete(key: _keyDepotId);
    await _storage.delete(key: _keyPenggunaId);
    await _storage.delete(key: _keyNamaPengguna);
    await _storage.delete(key: _keyNamaPengelola);
  }

  /// Cek apakah ada sesi tersimpan.
  Future<bool> hasSession() async {
    final depotId = await _storage.read(key: _keyDepotId);
    return depotId != null;
  }
}

class SavedSession {
  final String depotId;
  final String penggunaId;
  final String namaPengguna;
  final String namaPengelola;

  SavedSession({
    required this.depotId,
    required this.penggunaId,
    required this.namaPengguna,
    required this.namaPengelola,
  });
}
