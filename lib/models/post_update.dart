class PostUpdate {
  final String? title;
  final String? description;
  final String? code;
  final bool? isResolved;

  const PostUpdate({this.title, this.description, this.code, this.isResolved});

  Map<String, dynamic> toJson() {
    if (title != null &&
        (title!.trim().length < 6 || title!.trim().length > 160)) {
      throw ArgumentError('O titulo deve ter entre 6 e 160 caracteres.');
    }
    if (description != null &&
        (description!.trim().length < 12 ||
            description!.trim().length > 10000)) {
      throw ArgumentError('A descricao deve ter entre 12 e 10000 caracteres.');
    }
    if (code != null && code!.length > 20000) {
      throw ArgumentError('O codigo deve ter no maximo 20000 caracteres.');
    }
    return {
      if (title != null) 'title': title!.trim(),
      if (description != null) 'description': description!.trim(),
      'code': ?code,
      'isResolved': ?isResolved,
    };
  }
}
