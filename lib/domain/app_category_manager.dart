class AppCategoryManager {
  static const String categoryEducation = 'Education';
  static const String categoryWork = 'Work';
  static const String categorySocial = 'Social Media';
  static const String categoryEntertainment = 'Entertainment';
  static const String categoryCommunication = 'Communication';
  static const String categoryGaming = 'Gaming';
  static const String categoryBrowser = 'Browser';
  static const String categoryProductivity = 'Productivity';
  static const String categoryOther = 'Other';

  static const List<String> allCategories = [
    categoryEducation,
    categoryWork,
    categoryProductivity,
    categorySocial,
    categoryEntertainment,
    categoryGaming,
    categoryCommunication,
    categoryBrowser,
    categoryOther,
  ];

  static final Map<String, String> _defaultPackageMap = {
    // Education
    'com.google.android.apps.classroom': categoryEducation,
    'org.coursera.android': categoryEducation,
    'com.udemy.android': categoryEducation,
    'com.duolingo': categoryEducation,
    'org.khanacademy.android': categoryEducation,

    // Work
    'com.slack': categoryWork,
    'com.microsoft.teams': categoryWork,
    'us.zoom.videomeetings': categoryWork,
    'com.google.android.apps.meetings': categoryWork,
    'com.trello': categoryWork,

    // Social Media
    'com.facebook.katana': categorySocial,
    'com.facebook.lite': categorySocial,
    'com.instagram.android': categorySocial,
    'com.zhiliaoapp.musically': categorySocial,
    'com.ss.android.ugc.trill': categorySocial,
    'com.twitter.android': categorySocial,
    'com.snapchat.android': categorySocial,
    'com.reddit.frontpage': categorySocial,

    // Entertainment
    'com.google.android.youtube': categoryEntertainment,
    'com.netflix.mediaclient': categoryEntertainment,
    'com.spotify.music': categoryEntertainment,
    'tv.twitch.android.app': categoryEntertainment,

    // Communication
    'com.whatsapp': categoryCommunication,
    'com.facebook.orca': categoryCommunication,
    'org.telegram.messenger': categoryCommunication,

    // Gaming
    'com.tencent.ig': categoryGaming,
    'com.dts.freefireth': categoryGaming,
    'com.mobile.legends': categoryGaming,
    'com.roblox.client': categoryGaming,

    // Browser
    'com.android.chrome': categoryBrowser,
    'org.mozilla.firefox': categoryBrowser,

    // Productivity
    'notion.id': categoryProductivity,
    'com.google.android.keep': categoryProductivity,
    'com.google.android.calendar': categoryProductivity,
    'com.google.android.apps.docs': categoryProductivity,
  };

  static String getCategoryForPackage(String packageName, [Map<String, String>? customMap]) {
    if (customMap != null && customMap.containsKey(packageName)) {
      return customMap[packageName]!;
    }
    if (_defaultPackageMap.containsKey(packageName)) {
      return _defaultPackageMap[packageName]!;
    }

    final lower = packageName.toLowerCase();
    if (lower.contains('game') || lower.contains('play')) return categoryGaming;
    if (lower.contains('study') || lower.contains('learn') || lower.contains('edu')) return categoryEducation;
    if (lower.contains('social') || lower.contains('chat')) return categorySocial;
    if (lower.contains('browser')) return categoryBrowser;
    if (lower.contains('media') || lower.contains('video') || lower.contains('music')) return categoryEntertainment;
    if (lower.contains('office') || lower.contains('notes') || lower.contains('task')) return categoryProductivity;

    return categoryOther;
  }

  static bool isProductive(String category) {
    return category == categoryEducation || category == categoryWork || category == categoryProductivity;
  }

  static bool isDistracting(String category) {
    return category == categorySocial || category == categoryEntertainment || category == categoryGaming;
  }
}
