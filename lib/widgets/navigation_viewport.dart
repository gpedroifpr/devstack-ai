import 'package:flutter/material.dart';

/// Keeps scroll offsets per screen without keeping hidden screens subscribed.
class NavigationViewport extends StatefulWidget {
  const NavigationViewport({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  State<NavigationViewport> createState() => _NavigationViewportState();
}

class _NavigationViewportState extends State<NavigationViewport> {
  final _bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _bucket,
    child: KeyedSubtree(
      key: PageStorageKey(widget.location),
      child: widget.child,
    ),
  );
}
