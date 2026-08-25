/// The signed-in user.
///
/// Not in the original port list, but the reference controller calls
/// `UserModel.fromJson(commonResponse.data)` and reads
/// `userModel.authentication?.accessToken`, so the foundation needs it.
///
/// [fromJson] takes the `data` object the auth endpoints return —
/// `{ user: {...}, token: "..." }` — and flattens it, keeping the demo-app's
/// nested `authentication.accessToken` accessor so ported screens are
/// unchanged while still matching this backend's actual shape.
class UserModel {
  int? id;
  String? name;
  String? email;
  String? role;
  String? emailVerifiedAt;
  String? createdAt;
  bool mustChangePassword = false;
  Authentication? authentication;

  UserModel({
    this.id,
    this.name,
    this.email,
    this.role,
    this.emailVerifiedAt,
    this.createdAt,
    this.authentication,
  });

  UserModel.fromJson(Map<String, dynamic> json) {
    // Accepts either the wrapped `{user: {...}, token: ...}` payload from the
    // auth endpoints or a bare user object from /api/user.
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    id = user['id'] as int?;
    name = user['name'] as String?;
    email = user['email'] as String?;
    role = user['role'] as String?;
    emailVerifiedAt = user['email_verified_at'] as String?;
    createdAt = user['created_at'] as String?;
    mustChangePassword = (user['must_change_password'] as bool?) ?? false;

    final token = json['token'];
    if (token is String && token.isNotEmpty) {
      authentication = Authentication(accessToken: token);
    }
  }

  bool get isEmailVerified => emailVerifiedAt != null;

  Map<String, dynamic> toJson() => {
        'user': {
          'id': id,
          'name': name,
          'email': email,
          'role': role,
          'email_verified_at': emailVerifiedAt,
          'created_at': createdAt,
          'must_change_password': mustChangePassword,
        },
        'token': authentication?.accessToken,
      };
}

class Authentication {
  String? accessToken;

  Authentication({this.accessToken});

  Authentication.fromJson(Map<String, dynamic> json) {
    accessToken = json['token'] as String? ?? json['accessToken'] as String?;
  }

  Map<String, dynamic> toJson() => {'accessToken': accessToken};
}
