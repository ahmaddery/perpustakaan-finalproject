import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentLanguage = 'id';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final language = await SettingsService.getLanguage();
      setState(() {
        _currentLanguage = language;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeLanguage(String languageCode) async {
    try {
      await SettingsService.saveLanguage(languageCode);
      setState(() {
        _currentLanguage = languageCode;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.getText('language_changed', languageCode),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.getText('error', _currentLanguage),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(LocalizationService.getText('settings', _currentLanguage)),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.getText('settings', _currentLanguage)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: Colors.purple,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          LocalizationService.getText('language', _currentLanguage),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Indonesian Option
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Text(
                          'ID',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        LocalizationService.getText('indonesian', _currentLanguage),
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: Radio<String>(
                        value: 'id',
                        groupValue: _currentLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                          }
                        },
                        activeColor: Colors.purple,
                      ),
                      onTap: () => _changeLanguage('id'),
                    ),
                    
                    const Divider(),
                    
                    // English Option
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          'EN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        LocalizationService.getText('english', _currentLanguage),
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: Radio<String>(
                        value: 'en',
                        groupValue: _currentLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                          }
                        },
                        activeColor: Colors.purple,
                      ),
                      onTap: () => _changeLanguage('en'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Info Card
            Card(
              elevation: 2,
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentLanguage == 'id'
                            ? 'Perubahan bahasa akan diterapkan ke seluruh aplikasi.'
                            : 'Language changes will be applied throughout the application.',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}