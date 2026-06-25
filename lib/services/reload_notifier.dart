import 'package:flutter/foundation.dart';

/// Singleton ChangeNotifier used to broadcast "data changed" events across
/// the IndexedStack screens without a full state-management library.
///
/// Call [notify] after any insert/update/delete so that Home, Records, and
/// Analytics all reload without requiring the user to manually pull-to-refresh.
class ReloadNotifier extends ChangeNotifier {
  static final ReloadNotifier instance = ReloadNotifier._();
  ReloadNotifier._();

  void notify() => notifyListeners();
}
