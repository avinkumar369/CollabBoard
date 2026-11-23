class BoardMember {
  final int id;
  final String name;
  final String role;

  BoardMember({required this.id, required this.name, required this.role});

  factory BoardMember.fromJson(Map<String, dynamic> json) {
    return BoardMember(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }
}
