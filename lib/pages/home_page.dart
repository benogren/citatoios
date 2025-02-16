import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:timeago/timeago.dart' as timeago;


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> emails = [];
  bool isLoading = true;
  final logger = Logger();
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final result = await supabase
          .from('newsletter_emails')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      setState(() {
        emails = result;
        isLoading = false;
      });
    } catch (error) {
      logger.e('Error fetching data: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    if (context.mounted) {
      Navigator.pop(context);
    }

    try {
      await supabase.auth.signOut();
    } catch (error) {
      logger.e('Error signing out: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCallbackEvent(ScrollDirection direction, ScrollSuccess success) {
  logger.i("Scroll callback received with data: {direction: $direction, success: $success}");
  if (success == ScrollSuccess.SUCCESS) { // Changed from success.name
    setState(() {
      currentIndex = direction == ScrollDirection.FORWARD ? 
          (currentIndex + 1).clamp(0, emails.length - 1) : 
          (currentIndex - 1).clamp(0, emails.length - 1);
    });
  }
}

  Widget buildDrawer() {
    return NavigationDrawer(
      backgroundColor: Colors.white,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Text(
            'Menu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(
          thickness: 1,
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.logout),
          label: Text('Sign Out'),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextButton(
            onPressed: _handleSignOut,
            child: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }

  void showFullSummary(BuildContext context, Map<String, dynamic> email) {
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        email['subject'] ?? 'Newsletter',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: email['ai_fullsummary'] ?? 'No detailed summary available',
                      styleSheet: MarkdownStyleSheet(
                        h3: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 124, 58, 237),
                        ),
                        p: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                        listBullet: const TextStyle(
                          color: Color.fromARGB(255, 124, 58, 237),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildFAB(BuildContext context) {
    if (emails.isEmpty) return Container();
    
    return SpeedDial(
      icon: Icons.more_vert,
      activeIcon: Icons.close,
      backgroundColor: Colors.white,
      foregroundColor: const Color.fromARGB(255, 124, 58, 237),
      children: [
        SpeedDialChild(
          child: const Icon(Icons.summarize),
          backgroundColor: Colors.white,
          foregroundColor: const Color.fromARGB(255, 124, 58, 237),
          label: 'Read Full Summary',
          onTap: () => showFullSummary(context, emails[currentIndex]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Controller controller = Controller()
      ..addListener((event) {
        _handleCallbackEvent(event.direction, event.success);
      });

    return Scaffold(
      drawer: buildDrawer(),
      floatingActionButton: buildFAB(context),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : emails.isEmpty
                  ? const Center(child: Text('No data available'))
                  : TikTokStyleFullPageScroller(
                      contentSize: emails.length,
                      swipePositionThreshold: 0.2,
                      swipeVelocityThreshold: 2000,
                      animationDuration: const Duration(milliseconds: 150),
                      controller: controller,
                      builder: (BuildContext context, int index) {
                        final email = emails[index];
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              stops: [0.1, 0.9],
                              colors: [
                                Color.fromARGB(255, 124, 58, 237),
                                Color.fromARGB(255, 55, 48, 163),
                              ],
                            )
                          ),
                          padding: const EdgeInsets.all(20),
                          child: SafeArea(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 52, bottom: 8),
                                  child: Text(
                                    timeago.format(DateTime.parse(email['created_at'])),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    email['subject'] ?? 'No subject',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      height: 1.2,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    email['from_name'] ?? ' ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email['ai_summary'] ?? 'No summary available',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.2,
                                            color: Colors.white70,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}