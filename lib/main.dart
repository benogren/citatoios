import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:citatoios/pages/start_page.dart';
import 'package:citatoios/pages/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();

 // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Analytics
  final analytics = FirebaseAnalytics.instance;
 
 print("Starting initialization...");
 
 await dotenv.load(fileName: ".env");
 print("Loaded environment variables");
 
 await Supabase.initialize(
   url: dotenv.env['SUPABASE_URL']!,
   anonKey: dotenv.env['SUPABASE_KEY']!,
  //  authOptions: FlutterAuthClientOptions(
  //    authFlowType: AuthFlowType.pkce,
  //  ),
 );
 print("Supabase initialized");

 runApp(const MyApp());
}

class MyApp extends StatefulWidget {
 const MyApp({super.key});

 // Create analytics instance
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  // Create analytics observer for navigation tracking
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

 @override
 State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
 late AppLinks _appLinks;
 bool _isInitialized = false;

 @override
 void initState() {
   super.initState();
   print("MyApp initState called");
   _initializeApp();
 }

 Future<void> _initializeApp() async {
   print("Starting _initializeApp");
   _appLinks = AppLinks();
   print("AppLinks instance created");

   try {
     print("Attempting to get initial link");
     final appStartLink = await _appLinks.getInitialLink();
     print("Got initial link: $appStartLink");

     if (appStartLink != null) {
       // Handle the deep link
       _handleDeepLink(appStartLink);
     }

     // Handle links when app is running
     _appLinks.uriLinkStream.listen(
       (uri) {
         print('Got uri: $uri');
         _handleDeepLink(uri);
       },
       onError: (err) {
         print('Got error from uri stream: $err');
       },
     );
     print("Uri stream listener set up");

   } catch (e) {
     print('Error in _initializeApp: $e');
   }

   print("Setting _isInitialized to true");
   if (mounted) {
     setState(() {
       _isInitialized = true;
     });
   }
   print("_isInitialized set to: $_isInitialized");
 }

 void _handleDeepLink(Uri uri) {
   print('Handling deep link: $uri');
   if (uri.path.contains('login-callback')) {
     // This is a login callback, let Supabase handle it
     supabase.auth.getSessionFromUrl(uri);
   }
 }

 @override
 Widget build(BuildContext context) {
   print("Building MyApp, _isInitialized: $_isInitialized");
   
   return MaterialApp(
     title: 'Citato.ai',
     debugShowCheckedModeBanner: false,
     theme: ThemeData(
       primarySwatch: Colors.blue,
       visualDensity: VisualDensity.adaptivePlatformDensity,
     ),
     home: _isInitialized 
         ? const StartPage()
         : const Scaffold(
             body: Center(
               child: CircularProgressIndicator(),
             ),
           ),
     routes: {
       '/start': (context) => const StartPage(),
       '/home': (context) => const HomePage(),
     },
   );
 }
}

// Get Supabase client
final supabase = Supabase.instance.client;