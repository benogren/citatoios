import 'package:flutter/material.dart';
import 'package:citatoios/pages/home_page.dart';
import 'package:citatoios/pages/start_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  /*Retrieve the current user and assign the value to the _user variable. Notice that
this page sets up a listener on the user's auth state using onAuthStateChange. */
  User? _user;
  @override
  void initState() {
    _getAuth();
    super.initState();
  }

  Future<void> _getAuth() async {
    setState(() {
      _user = supabase.auth.currentUser;
    });
    supabase.auth.onAuthStateChange.listen((event) {
      setState(() {
        _user = event.session?.user;
      });
    });
  }

  final SupabaseClient supabase = Supabase.instance.client;
  @override
  Widget build(BuildContext context) {
    return _user == null ? StartPage() : HomePage();
  }
}