class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String uiLayout;
  final bool aiEnabled;

  /// Whether the server has confirmed this email (issue #106). Null when the
  /// server didn't say (older server or stored user); the server's 403
  /// `email_verification_required` is the real lock, so null never locks.
  final bool? emailVerified;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    required this.uiLayout,
    required this.aiEnabled,
    this.emailVerified,
  });

  bool get isIntroLayout => uiLayout == 'intro';

  factory User.fromJson(Map<String, dynamic> json) {
    final verified = json['email_verified'] ?? json['emailVerified'];
    return User(
      id: json['id'].toString(),
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      uiLayout: _coerceUiLayout(json['ui_layout'] ?? json['uiLayout']),
      aiEnabled: _coerceBool(json['ai_enabled'] ?? json['aiEnabled'], defaultValue: false),
      emailVerified: verified == null ? null : _coerceBool(verified, defaultValue: false),
    );
  }

  static String _coerceUiLayout(dynamic value) {
    if (value is String) {
      final layout = value.trim();
      if (layout.isNotEmpty) return layout;
    }
    return 'dashboard';
  }

  static bool _coerceBool(dynamic value, {required bool defaultValue}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case "true":
        case "1":
        case "yes":
          return true;
        case "false":
        case "0":
        case "no":
          return false;
      }
    }

    return defaultValue;
  }

  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? uiLayout,
    bool? aiEnabled,
    bool? emailVerified,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      uiLayout: uiLayout ?? this.uiLayout,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'ui_layout': uiLayout,
      'ai_enabled': aiEnabled,
      'email_verified': emailVerified,
    };
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) {
      return firstName!;
    }
    return email;
  }
}
