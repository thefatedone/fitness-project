import 'app_localizations.dart';

/// Dynamic-key lookup helper for [AppLocalizations].
///
/// The generated class exposes one named getter per ARB entry — there's
/// no built-in `lookup(String)` because each entry has its own static
/// type (some take placeholder args). To support UI code that
/// dispatches on a runtime-known string (e.g. an `ApiException.messageKey`
/// coming back from the network layer), this extension provides a
/// switch-driven `lookup(String)` that resolves the small set of keys
/// the app actually uses at runtime. Adding a new key to this file
/// is the only required change when a new `messageKey` appears in the
/// provider layer.
extension AppLocalizationsLookup on AppLocalizations {
  /// Resolves [key] to the active locale's text, or returns `null`
  /// if the key isn't in this registry. Callers should fall back to
  /// the `message` field on the originating exception when this
  /// returns `null`.
  String? lookup(String key) {
    switch (key) {
      // Common.
      case 'commonError':
        return commonError;
      // Auth / network-layer failures.
      case 'authServerUnreachable':
        return authServerUnreachable;
      case 'authNoConnection':
        return authNoConnection;
      case 'authSecureConnectionFailed':
        return authSecureConnectionFailed;
      case 'authRequestCancelled':
        return authRequestCancelled;
      // Empty-response error (generic).
      case 'userFacingErrorServerEmpty':
        return userFacingErrorServerEmpty;
    }
    return null;
  }
}
