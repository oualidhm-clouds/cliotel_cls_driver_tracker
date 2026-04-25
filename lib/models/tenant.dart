class Tenant {
  final String id;
  final String name;
  final String slug;
  final String? domain;
  final String? baseUrl;

  Tenant({
    required this.id,
    required this.name,
    required this.slug,
    this.domain,
    this.baseUrl,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      domain: json['domain'],
      baseUrl: json['base_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'domain': domain,
      'base_url': baseUrl,
    };
  }

  @override
  String toString() => 'Tenant(id: $id, name: $name, slug: $slug)';
}
