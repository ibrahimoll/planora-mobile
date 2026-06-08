import 'package:flutter/material.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage.dart';
import 'data/auth_api.dart';
import 'models/auth_models.dart';

class AuthGate extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const AuthGate({super.key, required this.onThemeToggle});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isLoading = true;
  UserResponse? currentUser;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final hasToken = await TokenStorage.hasAccessToken();

      if (!hasToken) {
        if (!mounted) return;

        setState(() {
          currentUser = null;
          isLoading = false;
        });

        return;
      }

      final user = await AuthApi.getCurrentUser();

      if (!mounted) return;

      setState(() {
        currentUser = user;
        isLoading = false;
      });
    } on ApiException catch (error, stackTrace) {
      debugPrint('AuthGate current user load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        currentUser = buildSessionFallbackUser();
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('AuthGate session check failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        currentUser = buildSessionFallbackUser();
        isLoading = false;
      });
    }
  }

  UserResponse buildSessionFallbackUser() {
    return UserResponse(
      userId: 0,
      username: 'user',
      email: '',
      fullName: 'Planora User',
      role: 'user',
      isActive: true,
      isEmailVerified: true,
      profilePic: null,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _logout() async {
    await TokenStorage.clearAccessToken();

    if (!mounted) return;

    setState(() {
      currentUser = null;
      isLoading = false;
    });
  }

  void _updateCurrentUser(UserResponse user) {
    setState(() {
      currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = currentUser;

    if (user == null) {
      return OnboardingScreen(onThemeToggle: widget.onThemeToggle);
    }

    return HomeScreen(
      user: user,
      onThemeToggle: widget.onThemeToggle,
      onLoggedOut: _logout,
      onUserUpdated: _updateCurrentUser,
    );
  }
}
