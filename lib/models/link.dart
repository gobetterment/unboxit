class Link {
  final String id;
  final String title;
  final String url;
  final List<String> tags;
  final DateTime createdAt;
  final String description;
  final String memo;
  final String image;
  final String favicon;
  final String siteName;

  Link({
    required this.id,
    required this.title,
    required this.url,
    required this.tags,
    required this.createdAt,
    this.description = '',
    this.memo = '',
    this.image = '',
    this.favicon = '',
    this.siteName = '',
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      tags: List<String>.from(json['tags'] as List),
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      image: json['image'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'description': description,
      'memo': memo,
      'image': image,
      'favicon': favicon,
      'site_name': siteName,
    };
  }
}
