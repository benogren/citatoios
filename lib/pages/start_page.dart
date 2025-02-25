import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:citatoios/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:citatoios/pages/home_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

Session? _session;

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkCurrentSession();
  }

  Future<void> _checkCurrentSession() async {
    try {
      _session = await supabase.auth.currentSession;
      if (_session != null && mounted) {
         Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomePage(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      if (event == AuthChangeEvent.signedIn) {
        debugPrint("Closing any remaining web views...");
        if (Platform.isIOS) {
          closeWebView();
        }
      }

      if (mounted) {
        if (event == AuthChangeEvent.signedIn && session != null) {
          debugPrint("Navigating to HomePage after sign in");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomePage(),
            ),
          );
        } else if (event == AuthChangeEvent.signedOut) {
          debugPrint("User signed out");
        }
      }
    });
  }

  Future<void> closeWebView() async {
    try {
      if (await canLaunchUrl(Uri.parse('about:blank'))) {
        await launchUrl(Uri.parse('about:blank'));
      }
    } catch (e) {
      debugPrint("Error closing web view: $e");
    }
  }

  Future<void> _googleSignIn() async {
    try {
      debugPrint("Starting Google Sign In...");
      final bool success = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.citatoios://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          'prompt': 'select_account',
        },
      );
      
      debugPrint("Sign in result: $success");
      
      if (success) {
        debugPrint("Waiting for session...");
        await Future.delayed(const Duration(milliseconds: 500));
        
        final currentSession = await supabase.auth.currentSession;
        debugPrint("Current session: ${currentSession != null}");
        
        if (currentSession != null && mounted) {
          setState(() {
            _session = currentSession;
          });
          
          debugPrint("Session established, navigating to HomePage");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomePage(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during Google sign in: $e');
      if (e is AuthException) {
        debugPrint('Auth error code: ${e.statusCode}');
        debugPrint('Auth error message: ${e.message}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            stops: [0.1, 0.9],
            colors: [
              Color.fromARGB(255, 124, 58, 237),
              Color.fromARGB(255, 55, 48, 163),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'citato.ai',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SignInButton(
                Buttons.Google,
                onPressed: _googleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}