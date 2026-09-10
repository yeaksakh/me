import 'package:flutter/foundation.dart' show ChangeNotifier, kReleaseMode;

import '../data/local_store.dart';

/// Which server the app signs in to.
///
/// Staff never see this. It exists so one build can be pointed at staging or at
/// an on-site server without shipping a separate flavour, and the choice
/// survives a restart so a tester does not re-enter it every launch. Same
/// behaviour as the rider app (`delivery_boy`), so the two are tested the same
/// way.
class ServerConfig extends ChangeNotifier {
  ServerConfig({LocalStore? store}) : _store = store {
    _restore();
  }

  /// Where a fresh install points.
  static const defaultUrl = 'https://yeaksa.com';

  /// Optional. Without a store the choice lives only for this run.
  final LocalStore? _store;

  String _baseUrl = defaultUrl;

  String get baseUrl => _baseUrl;
  bool get isDefault => _baseUrl == defaultUrl;

  /// True when this build may be pointed somewhere else at all.
  ///
  /// The switcher is a development tool. A SHIPPED app that can be repointed at
  /// an arbitrary host -- and remembers it across restarts -- is both a support
  /// call nobody can diagnose from the outside and a way to feed a staff
  /// member's password to a host the shop does not control.
  static bool get canOverride => !kReleaseMode;

  /// Stores [value] for this and future launches.
  ///
  /// Returns null when accepted, or the reason it was rejected so the caller
  /// can show it against the field.
  Future<String?> setBaseUrl(String value) async {
    if (!canOverride) return null;
    final cleaned = normalise(value);
    if (cleaned == null) {
      return 'Enter a full address, e.g. $defaultUrl';
    }
    if (cleaned == _baseUrl) return null;
    _baseUrl = cleaned;
    notifyListeners();
    await _store?.saveServerUrl(cleaned);
    return null;
  }

  Future<void> resetToDefault() => setBaseUrl(defaultUrl);

  /// Hostnames, IPv4 and IPv6 only. Without this, `Uri` happily percent-encodes
  /// prose into a "valid" host, so a typo would be saved as a real server.
  static final _host = RegExp(r'^[A-Za-z0-9.\-:]+$');

  /// Trims [value] to a bare origin, treating `example.com` as shorthand for
  /// `https://example.com`. Query, fragment and trailing slashes are dropped so
  /// the result can be joined to a path directly. Null when it is not an
  /// http(s) address.
  static String? normalise(String value) {
    var text = value.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (!uri.isScheme('http') && !uri.isScheme('https')) return null;
    if (uri.host.isEmpty || !_host.hasMatch(uri.host)) return null;

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceAll(RegExp(r'/+$'), ''),
    ).toString();
  }

  /// Bring back the previously chosen server. A stored value that no longer
  /// parses is ignored rather than stranding the app on a broken address.
  Future<void> _restore() async {
    if (!canOverride) {
      // CLEARED, not merely ignored: upgrading a handset from a debug build to
      // a release one must not leave it quietly pointing at a test box.
      _baseUrl = defaultUrl;
      await _store?.clearServerUrl();
      return;
    }
    final saved = await _store?.loadServerUrl();
    if (saved == null) return;
    final cleaned = normalise(saved);
    if (cleaned == null || cleaned == _baseUrl) return;
    _baseUrl = cleaned;
    notifyListeners();
  }
}
