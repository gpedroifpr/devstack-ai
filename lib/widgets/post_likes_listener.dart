import 'package:flutter/material.dart';

class PostLikesListener extends StatefulWidget {
  final String postId;
  final Stream<Set<String>> Function(String) watchLikes;
  final Widget Function(AsyncSnapshot<Set<String>>, VoidCallback) builder;

  const PostLikesListener({
    super.key,
    required this.postId,
    required this.watchLikes,
    required this.builder,
  });

  @override
  State<PostLikesListener> createState() => _PostLikesListenerState();
}

class _PostLikesListenerState extends State<PostLikesListener> {
  late Stream<Set<String>> _stream;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _stream = widget.watchLikes(widget.postId);
  }

  @override
  void didUpdateWidget(covariant PostLikesListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) _renew();
  }

  void _renew() {
    _stream = widget.watchLikes(widget.postId);
    _revision++;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      key: ValueKey(_revision),
      stream: _stream,
      builder: (context, snapshot) =>
          widget.builder(snapshot, () => setState(_renew)),
    );
  }
}
