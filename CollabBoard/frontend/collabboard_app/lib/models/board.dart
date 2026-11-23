class Board {
  final int id;
  final String title;
  final String description;
  final int ownerId;

  Board({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] is int ? json['id'] : int.parse((json['id'] ?? 0).toString()),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ownerId: json['ownerId'] != null
          ? (json['ownerId'] is int ? json['ownerId'] : int.parse(json['ownerId'].toString()))
          : (json['owner_id'] != null
              ? (json['owner_id'] is int ? json['owner_id'] : int.parse(json['owner_id'].toString()))
              : 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
      };
}
