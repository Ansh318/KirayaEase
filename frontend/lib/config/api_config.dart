/// API Configuration
/// Change this to switch between localhost and production
class ApiConfig {
  // Production backend (Heroku)
  static const String baseUrl = 'https://kiraya-ease-50d651c2ed49.herokuapp.com';
  
  // Helper methods for common endpoints
  static String get chatbotEndpoint => '$baseUrl/chatbot';
  static String get userProfileEndpoint => '$baseUrl/user-profile';
  static String get userStatusEndpoint => '$baseUrl/user-status';
  static String get createPaymentOrderEndpoint => '$baseUrl/create-payment-order';
  static String get extractLeaseContentEndpoint => '$baseUrl/extract-lease-content';
  static String get digioKycEndpoint => '$baseUrl/digio-kyc';
}
