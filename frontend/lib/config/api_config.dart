/// API Configuration
/// Change this to switch between localhost and production
class ApiConfig {
  // Local backend
  static const String baseUrl =
      'https://kiraya-ease-50d651c2ed49.herokuapp.com';

  // Helper methods for common endpoints
  static String get chatbotEndpoint => '$baseUrl/agent-chat';
  static String get userProfileEndpoint => '$baseUrl/user-profile';
  static String get userStatusEndpoint => '$baseUrl/user-status';
  static String get createPaymentOrderEndpoint =>
      '$baseUrl/create-payment-order';
  static String get verifyPaymentEndpoint => '$baseUrl/verify-payment';
  static String get extractLeaseContentEndpoint =>
      '$baseUrl/extract-lease-content';
  static String get digioKycEndpoint => '$baseUrl/digio-kyc';
  static String get googleLoginEndpoint => '$baseUrl/auth-google';
  static String get onboardingEndpoint => '$baseUrl/onboarding';
  static String get leasesEndpoint => '$baseUrl/leases';
  static String get propertiesEndpoint => '$baseUrl/properties';
  static String get paymentsEndpoint => '$baseUrl/payments';
}
