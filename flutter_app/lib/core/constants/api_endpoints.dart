/// API endpoint paths for the Kita English backend.
class ApiEndpoints {
  ApiEndpoints._();

  /// Base URL for the API server.
  static const String baseUrl = 'https://backend-production-3908.up.railway.app/api/v1';

  // Auth
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authGuest = '/auth/guest';
  static const String authLink = '/auth/link';

  // Kid profile
  static const String kidProfiles = '/kids';
  static String kidProfile(String kidId) => '/kids/$kidId';
  static String kidProfileUpdate(String kidId) => '/kids/$kidId';
  static String kidPlacement(String kidId) => '/kids/$kidId/placement';

  // Sessions
  static String sessions(String kidId) => '/kids/$kidId/sessions';
  static String session(String kidId, int day) =>
      '/kids/$kidId/sessions/$day';
  static String sessionStart(String kidId, int day) =>
      '/kids/$kidId/sessions/$day/start';
  static String sessionComplete(String kidId, int day) =>
      '/kids/$kidId/sessions/$day/complete';

  // Activities
  static String activityResult(String kidId, String activityId) =>
      '/kids/$kidId/activities/$activityId/result';

  // Pronunciation
  static const String pronunciationScore = '/pronunciation/score';

  // SRS (Spaced Repetition)
  static String srsDueCards(String kidId) => '/kids/$kidId/srs/due';
  static String srsReview(String kidId) => '/kids/$kidId/srs/review';

  // Progress & Stats
  static String progressOverview(String kidId) => '/kids/$kidId/progress';
  static String progressVocabulary(String kidId) =>
      '/kids/$kidId/progress/vocabulary';
  static String progressPronunciation(String kidId) =>
      '/kids/$kidId/progress/pronunciation';
}
