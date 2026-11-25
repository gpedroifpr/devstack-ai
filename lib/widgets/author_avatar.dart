import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.radius,
    required this.color,
    this.photo,
    this.photos,
  });
  final double radius;
  final Color color;
  final String? photo;
  final Stream<String?>? photos;

  @override
  Widget build(BuildContext context) {
    if (photos == null) return _avatar(photo);
    return StreamBuilder<String?>(
      stream: photos,
      builder: (context, snapshot) => _avatar(snapshot.data),
    );
  }

  Widget _avatar(String? encoded) {
    Uint8List? bytes;
    try {
      if (encoded != null && encoded.isNotEmpty && encoded.length <= 819200) {
        bytes = base64Decode(encoded);
      }
    } on FormatException {
      // Invalid legacy images should not break the feed.
    }
    final fallback = Icon(Icons.person, size: radius, color: color);
    return SizedBox.square(
      dimension: radius * 2,
      child: ClipOval(
        child: ColoredBox(
          color: color.withValues(alpha: .18),
          child: bytes == null || bytes.isEmpty
              ? fallback
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}
