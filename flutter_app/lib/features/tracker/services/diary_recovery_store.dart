import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Nutritional recovery data is scoped to the API environment and account.
/// A failed local write must stop a destructive network action.
class DiaryRecoveryStore {
  final String namespace;
  static final _tails = <String, Future<void>>{};
  DiaryRecoveryStore({required String userId, required String environment})
    : namespace =
          'diary-recovery-v1:${Uri.encodeComponent(environment)}:${Uri.encodeComponent(userId)}';

  /// Serialize reads, cache writes and receipt removal across store instances.
  Future<T> _ordered<T>(Future<T> Function() operation) {
    final result = (_tails[namespace] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    _tails[namespace] = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }

  Future<Map<String, dynamic>?> read(String key) => _ordered(() async {
    final value = (await SharedPreferences.getInstance()).getString(
      '$namespace:$key',
    );
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  });

  Future<void> write(String key, Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    return _ordered(() async {
      final saved = await (await SharedPreferences.getInstance()).setString(
        '$namespace:$key',
        encoded,
      );
      if (!saved) throw StateError('Could not persist diary recovery data');
    });
  }

  Future<void> remove(String key) => _ordered(() async {
    final removed = await (await SharedPreferences.getInstance()).remove(
      '$namespace:$key',
    );
    if (!removed) throw StateError('Could not clear diary recovery data');
  });
}
