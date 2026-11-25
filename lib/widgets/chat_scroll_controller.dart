import 'package:flutter/widgets.dart';

class ChatScrollController extends ScrollController {
  int _request = 0;
  bool _disposed = false;
  bool _followGrowth = true;

  void cancelFollow() {
    _request++;
    _followGrowth = false;
  }

  void followGrowingResponse() {
    final request = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_followGrowth || request != _request || !hasClients) {
        return;
      }
      // Small increments follow newly rendered lines, never the unseen answer.
      if (position.extentAfter > 0) jumpTo(position.maxScrollExtent);
    });
  }

  void followLatest() {
    _followGrowth = true;
    final request = ++_request;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Lazy lists refine their extent as messages with different heights appear.
      for (var pass = 0; pass < 12; pass++) {
        if (_disposed || request != _request || !hasClients) return;
        await animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
        if (_disposed || request != _request || !hasClients) return;
        await WidgetsBinding.instance.endOfFrame;
        if (_disposed || request != _request || !hasClients) return;
        if (position.extentAfter < 1) return;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelFollow();
    super.dispose();
  }
}
