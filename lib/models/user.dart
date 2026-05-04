class User {
  int? id;
  String username;
  String email;
  String password;
  String? profileImage;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    this.profileImage,
  });

  // Convert User object to map (to store in SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'profile_image': profileImage,
    };
  }

  // Convert map to User object (from database)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      profileImage: map['profile_image'],
    );
  }
}