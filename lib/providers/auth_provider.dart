import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final MQTTService _mqttService = MQTTService();
  
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  
  // Initialize auth state from local storage
  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final token = prefs.getString('auth_token');
      
      if (userId != null && token != null) {
        _apiService.setToken(token);
        
        // Get user profile
        _currentUser = await _apiService.getUserProfile(userId);
        _isAuthenticated = true;
        
        // Connect to MQTT broker
        await _mqttService.connect(userId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing auth: $e');
      }
      // Clear any invalid auth data
      await logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Login user
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.login(email, password);
      
      // Save auth data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', response['user']['id']);
      await prefs.setString('auth_token', response['token']);
      
      _currentUser = User.fromJson(response['user']);
      _isAuthenticated = true;
      print("starting mqtt service");
      // Connect to MQTT broker
      await _mqttService.connect(_currentUser!.id);
      print("sucessfully completed mqtt");
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Register new user
  Future<void> register(String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _apiService.register(username, email, password);
      
      // Login after successful registration
      await login(email, password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Disconnect from MQTT broker
      _mqttService.disconnect();
      
      // Clear auth data
      _apiService.clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('auth_token');
      
      _currentUser = null;
      _isAuthenticated = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}