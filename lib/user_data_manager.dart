import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserDataManager {
  static const String _profileKey = 'user_profile';
  static UserDataManager? _instance;
  
  UserDataManager._internal();
  
  static UserDataManager get instance {
    _instance ??= UserDataManager._internal();
    return _instance!;
  }
  
  Map<String, dynamic>? _cachedProfile;
  
  Future<Map<String, dynamic>> getProfile() async {
    if (_cachedProfile != null) {
      return Map<String, dynamic>.from(_cachedProfile!);
    }
    
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_profileKey);
    
    if (profileJson != null) {
      try {
        _cachedProfile = jsonDecode(profileJson);
        return Map<String, dynamic>.from(_cachedProfile!);
      } catch (e) {
        print('Error loading cached profile: $e');
      }
    }
    
    // Return default profile if no cached data
    _cachedProfile = {
      'name': 'Demo User',
      'role': 'Employee (Demo)',
      'email': 'demo@example.com',
      'phone': '+1234567890',
      'image': '',
    };
    
    return Map<String, dynamic>.from(_cachedProfile!);
  }
  
  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedProfile = Map<String, dynamic>.from(profile);
    await prefs.setString(_profileKey, jsonEncode(_cachedProfile));
  }
  
  Future<void> updateField(String key, dynamic value) async {
    final profile = await getProfile();
    profile[key] = value;
    await updateProfile(profile);
  }
  
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    _cachedProfile = null;
  }
  
  void clearCache() {
    _cachedProfile = null;
  }
}