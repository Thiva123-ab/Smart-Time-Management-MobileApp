import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final String role;
  final String email;
  final String bio;
  final int dailyTargetHours;
  final int avatarIndex;
  final String phoneNumber;
  final String location;
  final String occupationField;
  final String linkedinUrl;
  final String githubUrl;
  final String portfolioUrl;
  final String joinedDate;

  UserProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.bio,
    required this.dailyTargetHours,
    required this.avatarIndex,
    this.phoneNumber = '',
    this.location = 'Colombo, Sri Lanka',
    this.occupationField = 'Software & Tech',
    this.linkedinUrl = '',
    this.githubUrl = '',
    this.portfolioUrl = '',
    this.joinedDate = 'Oct 2026',
  });

  static const String _keyName = 'profile_user_name';
  static const String _keyRole = 'profile_user_role';
  static const String _keyEmail = 'profile_user_email';
  static const String _keyBio = 'profile_user_bio';
  static const String _keyTarget = 'profile_daily_target_hours';
  static const String _keyAvatar = 'profile_avatar_index';
  static const String _keyPhone = 'profile_user_phone';
  static const String _keyLocation = 'profile_user_location';
  static const String _keyOccupation = 'profile_user_occupation';
  static const String _keyLinkedin = 'profile_user_linkedin';
  static const String _keyGithub = 'profile_user_github';
  static const String _keyPortfolio = 'profile_user_portfolio';
  static const String _keyJoinedDate = 'profile_user_joined_date';

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString(_keyName) ?? 'Focus User',
      role: prefs.getString(_keyRole) ?? 'Productivity Enthusiast',
      email: prefs.getString(_keyEmail) ?? 'user@focusflow.app',
      bio: prefs.getString(_keyBio) ?? 'Dedicated to high performance, continuous learning, and mindful digital habits.',
      dailyTargetHours: prefs.getInt(_keyTarget) ?? 4,
      avatarIndex: prefs.getInt(_keyAvatar) ?? 0,
      phoneNumber: prefs.getString(_keyPhone) ?? '+94 77 123 4567',
      location: prefs.getString(_keyLocation) ?? 'Colombo, Sri Lanka',
      occupationField: prefs.getString(_keyOccupation) ?? 'Software & Tech',
      linkedinUrl: prefs.getString(_keyLinkedin) ?? 'linkedin.com/in/focususer',
      githubUrl: prefs.getString(_keyGithub) ?? 'github.com/focususer',
      portfolioUrl: prefs.getString(_keyPortfolio) ?? 'focusflow.app/me',
      joinedDate: prefs.getString(_keyJoinedDate) ?? 'Oct 2026',
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
    await prefs.setString(_keyPhone, phoneNumber);
    await prefs.setString(_keyLocation, location);
    await prefs.setString(_keyOccupation, occupationField);
    await prefs.setString(_keyLinkedin, linkedinUrl);
    await prefs.setString(_keyGithub, githubUrl);
    await prefs.setString(_keyPortfolio, portfolioUrl);
    await prefs.setString(_keyJoinedDate, joinedDate);
  }

  UserProfile copyWith({
    String? name,
    String? role,
    String? email,
    String? bio,
    int? dailyTargetHours,
    int? avatarIndex,
    String? phoneNumber,
    String? location,
    String? occupationField,
    String? linkedinUrl,
    String? githubUrl,
    String? portfolioUrl,
    String? joinedDate,
  }) {
    return UserProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      dailyTargetHours: dailyTargetHours ?? this.dailyTargetHours,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      occupationField: occupationField ?? this.occupationField,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      joinedDate: joinedDate ?? this.joinedDate,
    );
  }
}
