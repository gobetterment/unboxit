class Link {
  final String id;
  final String title;
  final String url;
  final List<String> tags;
  final String? description;
  final String? memo;
  final String? image;
  final String? favicon;
  final DateTime createdAt;

  Link({
    required this.id,
    required this.title,
    required this.url,
    required this.tags,
    this.description,
    this.memo,
    this.image,
    this.favicon,
    required this.createdAt,
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      tags: List<String>.from(json['tags'] as List),
      description: json['description'] as String?,
      memo: json['memo'] as String?,
      image: json['image'] as String?,
      favicon: json['favicon'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'tags': tags,
      'description': description,
      'memo': memo,
      'image': image,
      'favicon': favicon,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
