import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final String role;
  final String email;
  final String bio;
  final int dailyTargetHours;
  final int avatarIndex;

  UserProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.bio,
    required this.dailyTargetHours,
    required this.avatarIndex,
  });

  static const String _keyName = 'profile_user_name';
  static const String _keyRole = 'profile_user_role';
  static const String _keyEmail = 'profile_user_email';
  static const String _keyBio = 'profile_user_bio';
  static const String _keyTarget = 'profile_daily_target_hours';
  static const String _keyAvatar = 'profile_avatar_index';

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString(_keyName) ?? 'Focus User',
      role: prefs.getString(_keyRole) ?? 'Productivity Enthusiast',
      email: prefs.getString(_keyEmail) ?? 'user@focusflow.app',
      bio: prefs.getString(_keyBio) ?? 'Focusing on building better daily habits and managing time effectively.',
      dailyTargetHours: prefs.getInt(_keyTarget) ?? 4,
      avatarIndex: prefs.getInt(_keyAvatar) ?? 0,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyBio, bio);
    await prefs.setInt(_keyTarget, dailyTargetHours);
    await prefs.setInt(_keyAvatar, avatarIndex);
  }

  UserProfile copyWith({
    String? name,
    String? role,
    String? email,
    String? bio,
    int? dailyTargetHours,
    int? avatarIndex,
  }) {
    return UserProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      dailyTargetHours: dailyTargetHours ?? this.dailyTargetHours,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }
}
