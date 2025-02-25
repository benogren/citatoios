import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> unifiedContent = [];
  bool isLoading = true;
  final logger = Logger();
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchUnifiedData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchUnifiedData() async {
    if (!mounted) return;
    
    try {
      // Fetch newsletters
      final emailsResult = await supabase
          .from('newsletter_emails')
          .select()
          .order('received_at', ascending: false)
          .limit(20);
          
      // Fetch bookmarks
      final bookmarksResult = await supabase
          .from('bookmarks')
          .select()
          .eq('status', 'processed')
          .order('created_at', ascending: false)
          .limit(20);

      // Convert results to the same format and add type identifier
      final List<Map<String, dynamic>> emails = List<Map<String, dynamic>>.from(emailsResult)
          .map((email) => {
                ...Map<String, dynamic>.from(email),
                'type': 'newsletter',
                'display_date': email['received_at'], // Use received_at for newsletters
              })
          .toList();

      final List<Map<String, dynamic>> bookmarks = List<Map<String, dynamic>>.from(bookmarksResult)
          .map((bookmark) => {
                ...Map<String, dynamic>.from(bookmark),
                'type': 'bookmark',
                'display_date': bookmark['created_at'], // Use created_at for bookmarks
              })
          .toList();

      // Combine and sort both lists
      List<Map<String, dynamic>> combined = [...emails, ...bookmarks];
      combined.sort((a, b) => DateTime.parse(b['display_date'])
          .compareTo(DateTime.parse(a['display_date'])));

      if (mounted) {
        setState(() {
          unifiedContent = combined;
          isLoading = false;
        });
      }
    } catch (error) {
      logger.e('Error fetching unified data: $error');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    if (!mounted) return;

    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      logger.e('Error signing out: $error');
      if (mounted) {
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
    if (!mounted) return;
    
    logger.i("Scroll callback received with data: {direction: $direction, success: $success}");
    if (success == ScrollSuccess.SUCCESS) {
      setState(() {
        currentIndex = direction == ScrollDirection.FORWARD ? 
            (currentIndex + 1).clamp(0, unifiedContent.length - 1) : 
            (currentIndex - 1).clamp(0, unifiedContent.length - 1);
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
        const Divider(thickness: 1),
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

  void _showFullSummary(BuildContext context, Map<String, dynamic> content) {
    if (!mounted || content['type'] != 'newsletter') return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
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
                          content['subject'] ?? 'Newsletter',
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
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(
                      data: content['ai_fullsummary'] ?? 'No detailed summary available',
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
              ],
            );
          },
        );
      },
    );
  }

  void _showFullSummaryBookmark(BuildContext context, Map<String, dynamic> content) {
    if (!mounted || content['type'] != 'bookmark') return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
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
                          content['title'] ?? 'Bookmark',
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
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(
                      data: content['ai_fullysummary'] ?? 'No detailed summary available',
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
              ],
            );
          },
        );
      },
    );
  }

  void _showOriginal(BuildContext context, Map<String, dynamic> content) {
    if (!mounted || content['type'] != 'newsletter') return;

    // Decode base64 HTML content
    String htmlContent = '';
    try {
      if (content['html_base64'] != null) {
        final bytes = base64.decode(content['html_base64']);
        htmlContent = utf8.decode(bytes);
      } else {
        htmlContent = content['html_body'] ?? 'No content available';
      }
    } catch (e) {
      logger.e('Error decoding HTML content: $e');
      htmlContent = 'Error decoding content';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
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
                          content['subject'] ?? 'Newsletter',
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
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                        ),
                        child: HtmlWidget(
                          htmlContent,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          customWidgetBuilder: (element) {
                            if (element.localName == 'img') {
                              return const SizedBox.shrink(); // Skip images
                            }
                            return null;
                          },
                          onErrorBuilder: (context, element, error) => Text(
                            'Error rendering element: $element',
                            style: const TextStyle(color: Colors.red),
                          ),
                          onLoadingBuilder: (context, element, loadingProgress) =>
                              const CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Widget buildContentCard(Map<String, dynamic> item) {
    if (item['type'] == 'newsletter') {
      return buildNewsletterCard(item);
    } else {
      return buildBookmarkCard(item);
    }
  }

  Widget buildNewsletterCard(Map<String, dynamic> email) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 52, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, 
                    size: 16, 
                    color: Colors.black38
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(DateTime.parse(email['received_at'])),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showOriginal(context, email),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 2),
                child: Text(
                  email['subject'] ?? 'No subject',
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.1,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: Text(
                email['from_name'] ?? ' ',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
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
                        height: 1.4,
                        color: Colors.black87,
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
  }

  Widget buildBookmarkCard(Map<String, dynamic> bookmark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 52, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_border_rounded, 
                    size: 16, 
                    color: Colors.black38
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(DateTime.parse(bookmark['created_at'])),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final url = bookmark['url'];
                if (url != null) {
                  await launchUrl(Uri.parse(url));
                }
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 2),
                child: Text(
                    bookmark['title'] ?? 'Untitled Bookmark',
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.1,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: Text(
                bookmark['url'] ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (bookmark['ai_summary'] != null && bookmark['ai_summary'].toString().isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark['ai_summary'],
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.black87,
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
  }

  Widget buildFAB(BuildContext context) {
    if (unifiedContent.isEmpty) return Container();
    
    final currentItem = unifiedContent[currentIndex];
    
    if (currentItem['type'] == 'newsletter') {
      return SpeedDial(
        icon: Icons.more_vert,
        activeIcon: Icons.close,
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 124, 58, 237),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.bolt_rounded),
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 124, 58, 237),
            label: 'Read Full Summary',
            onTap: () => _showFullSummary(context, currentItem),
          ),
          SpeedDialChild(
            child: const Icon(Icons.notes),
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 124, 58, 237),
            label: 'View Original',
            onTap: () => _showOriginal(context, currentItem),
          ),
        ],
      );
    } else {
      // For bookmarks, show a simple FAB to open the URL
      // return FloatingActionButton(
      //   backgroundColor: Colors.white,
      //   foregroundColor: const Color.fromARGB(255, 124, 58, 237),
      //   child: const Icon(Icons.open_in_new),
      //   onPressed: () async {
      //     final url = currentItem['url'];
      //     if (url != null) {
      //       // TODO: Implement URL launching
      //       // await launchUrl(Uri.parse(url));
      //     }
      //   },
      // );
      return SpeedDial(
        icon: Icons.more_vert,
        activeIcon: Icons.close,
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 124, 58, 237),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.bolt_rounded),
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 124, 58, 237),
            label: 'Read Full Summary',
            onTap: () => _showFullSummaryBookmark(context, currentItem),
          ),
          SpeedDialChild(
            child: const Icon(Icons.link),
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 124, 58, 237),
            label: 'View Original',
            onTap: () async {
              final url = currentItem['url'];
              if (url != null) {
                await launchUrl(Uri.parse(url));
              }
            },
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(),
      floatingActionButton: buildFAB(context),
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (unifiedContent.isEmpty)
            const Center(child: Text('No content available'))
          else
            TikTokStyleFullPageScroller(
              contentSize: unifiedContent.length,
              swipePositionThreshold: 0.2,
              swipeVelocityThreshold: 2000,
              animationDuration: const Duration(milliseconds: 150),
              controller: Controller()
                ..addListener((event) {
                  _handleCallbackEvent(event.direction, event.success);
                }),
              builder: (BuildContext context, int index) {
                return buildContentCard(unifiedContent[index]);
              },
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color.fromARGB(255, 124, 58, 237)),
                onPressed: () {
                  if (mounted) {
                    Scaffold.of(context).openDrawer();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}