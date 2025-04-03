import 'dart:io' show Platform;

class ApiConfig {
  // Use localhost for iOS simulator, 10.0.2.2 for Android emulator
  static String get baseUrl {
    if (Platform.isIOS) {
      return 'http://localhost:8000';
    } else {
      return 'http://10.0.2.2:8000';
    }
  }

  static String get loginUrl => '$baseUrl/api/auth/login';
  static String get registerUrl => '$baseUrl/api/auth/register';
  static String get expenseUrl => '$baseUrl/api/transactions/expense';
  static String get incomeUrl => '$baseUrl/api/transactions/income';
  static String get transactionsUrl => '$baseUrl/api/transactions';
  static String get categoriesUrl => '$baseUrl/api/categories';
}
