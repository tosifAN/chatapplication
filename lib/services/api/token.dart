
class ApiAuthTokenService {
  String? _token;
  
  // Singleton pattern
  static final ApiAuthTokenService _instance = ApiAuthTokenService._internal();
  
  factory ApiAuthTokenService() {
    return _instance;
  }
  
  ApiAuthTokenService._internal();
  
  // Set auth token after login
  void setToken(String token) {
    _token = token;
  }
  
  // Clear token on logout
  void clearToken() {
    _token = null;
  }

  // Getter for token
  String? get token => _token;
}