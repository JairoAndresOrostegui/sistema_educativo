import 'package:flutter/material.dart';
import '../models/user/user_model_v2.dart';

class UserProviderV2 extends ChangeNotifier {
  userModelv2? _user;

  userModelv2? get user => _user;
  bool get isLoggedIn => _user != null;

  void setUser(userModelv2 user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  void updateFcmToken(String token) {
    if (_user == null) return;
    if (_user!.fcmToken == token) return; // evita rebuilds innecesarios
    _user = _user!.copyWith(fcmToken: token);
    notifyListeners();
  }

  void setActiveStudentId(String studentId) {
    if (_user == null) return;
    if (_user!.activeStudentId == studentId) {
      return; // evita rebuilds innecesarios
    }
    _user = _user!.copyWith(activeStudentId: studentId);
    notifyListeners();
  }
}
