import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class UserService {
  static final UserService instance = UserService._internal();

  factory UserService() {
    return instance;
  }

  UserService._internal();

  final ValueNotifier<String> name = ValueNotifier<String>("John Doe");
  final ValueNotifier<String> email = ValueNotifier<String>("");
  final ValueNotifier<String> role = ValueNotifier<String>("Elite Driver");
  final ValueNotifier<int> safetyScore = ValueNotifier<int>(98);
  final ValueNotifier<double> totalMiles = ValueNotifier<double>(0.0);
  final ValueNotifier<String?> profileImage = ValueNotifier<String?>(null);

  void setUser(String newName, String newEmail, {int score = 98, double miles = 0.0, String? imageUrl}) {
    name.value = newName.isNotEmpty ? newName : "Driver";
    email.value = newEmail;
    safetyScore.value = score;
    totalMiles.value = miles;
    profileImage.value = imageUrl;
  }
  
  void updateStats(int score, double miles) {
    safetyScore.value = score;
    totalMiles.value = miles;
    // Persist to backend logic can go here (or tracked separately)
  }

  Future<void> uploadProfileImage(dynamic imageFile) async {
     final String userEmail = email.value;
     if (userEmail.isEmpty) return;
     
     final String baseUrl = AppConfig.baseUrl;

     var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload_avatar'));
     request.fields['email'] = userEmail;
     
     // Handle both File (Cross File) and path
     String path = imageFile.path;
     request.files.add(await http.MultipartFile.fromPath('file', path));
     
     try {
       var streamedResponse = await request.send();
       var response = await http.Response.fromStream(streamedResponse);
       
       if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         // Construct full URL
         final String relativeUrl = data['url'];
         final String fullUrl = '${AppConfig.baseUrlWithoutApi}$relativeUrl';
            
         profileImage.value = fullUrl;
         print("Profile Image Updated: $fullUrl");
       } else {
         print("Upload failed: ${response.body}");
       }
     } catch (e) {
       print("Error uploading image: $e");
     }
  }

  Future<void> updateName(String newName) async {
    // Optimistic Update
    name.value = newName;
    
    // Sync with Backend
    final String userEmail = email.value;
    if (userEmail.isEmpty) return; // Can't sync purely local or demo user without ID

    final String baseUrl = AppConfig.baseUrl;
        
    try {
      await http.post(
        Uri.parse('$baseUrl/update_profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail,
          'name': newName,
        }),
      );
    } catch (e) {
      print("Failed to sync profile update: $e");
      // Optionally revert or show error, but for now we keep optimistic UI
    }
  }

  void logout() {
    name.value = "John Doe";
    email.value = "";
  }
}
