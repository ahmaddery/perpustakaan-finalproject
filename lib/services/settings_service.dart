import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String _languageKey = 'app_language';
  
  static Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(_languageKey) ?? 'id';
    
    return AppSettings(language: language);
  }
  
  static Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }
  
  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'id';
  }
}