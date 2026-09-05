import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/token_storage.dart';
import '../core/constants/api_constants.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

class ServerSettingsNotifier extends StateNotifier<String> {
  final TokenStorage _storage;

  ServerSettingsNotifier(this._storage) : super(ApiConstants.defaultBaseUrl) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.getBaseUrl();
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setBaseUrl(String newUrl) async {
    var formatted = newUrl.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    state = formatted;
    await _storage.saveBaseUrl(formatted);
  }
}

final serverSettingsProvider =
    StateNotifierProvider<ServerSettingsNotifier, String>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ServerSettingsNotifier(storage);
});
