import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionExpiryProvider = NotifierProvider<SessionExpiryNotifier, int>(
  SessionExpiryNotifier.new,
);

class SessionExpiryNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notifyExpired() {
    state++;
  }
}
