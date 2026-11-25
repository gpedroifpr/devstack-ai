import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';

/// Only animates presentation; callers retain the complete response for storage.
class ResponseRevealController extends ChangeNotifier {
  Timer? _timer;
  List<String> _characters = [];
  int _visible = 0;
  String get text => _characters.take(_visible).join();
  bool get isRevealing => _visible < _characters.length;

  void start(String text, {bool animate = true}) {
    _timer?.cancel();
    _characters = text.characters.toList();
    _visible = animate ? min(8, _characters.length) : _characters.length;
    notifyListeners();
    if (!isRevealing) return;
    final step = max(8, (_characters.length / 300).ceil());
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      _visible = min(_characters.length, _visible + step);
      if (!isRevealing) _timer?.cancel();
      notifyListeners();
    });
  }

  void finish() {
    _timer?.cancel();
    _visible = _characters.length;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
