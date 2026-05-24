class UserInfo {
  const UserInfo({
    required this.userId,
    required this.email,
    this.name,
    this.photoUrl,
  });

  final String userId;
  final String email;
  final String? name;
  final String? photoUrl;

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        userId: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
        photoUrl: json['photo_url'] as String?,
      );

  // Serializes to key/value pairs for the UserSession table.
  Map<String, String> toSessionEntries() => {
        'user_id': userId,
        'user_email': email,
        if (name != null) 'user_name': name!,
        if (photoUrl != null) 'user_photo_url': photoUrl!,
      };

  // Deserializes from UserSession table rows.
  static UserInfo? fromSessionEntries(Map<String, String?> map) {
    final userId = map['user_id'];
    final email = map['user_email'];
    if (userId == null || email == null) return null;
    return UserInfo(
      userId: userId,
      email: email,
      name: map['user_name'],
      photoUrl: map['user_photo_url'],
    );
  }
}
