import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/widgets/user_avatar.dart';

import 'package:crowdpass/services/developer_service.dart';

class DrawerMenu extends ConsumerWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the authProvider to get the current user.
    final user = ref.watch(authProvider).value;
    
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Non-scrollable top section
            Padding(
              padding: const EdgeInsets.all(16),
              child: user != null
                  ? Center(
                      child: UserAvatar.medium(
                        displayName: user.displayName,
                        photoURL: user.photoURL,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/user/',
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Sign In'),
                          onPressed: () {
                            Navigator.pushNamed(context, '/sign_in/');
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add),
                          label: const Text('Create Account'),
                          onPressed: () {
                            Navigator.pushNamed(context, '/sign_up/');
                          },
                        ),
                      ],
                    ),
            ),
            
            const Divider(),

            // Scrollable list section
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Home'),
                    onTap: () => Navigator.pop(context),
                  ),
                  if (user != null) ...[
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('My Profile'),
                      onTap: () {
                         Navigator.pop(context); // Close the drawer first
                         Navigator.pushNamed(context, '/user/');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.business),
                      title: const Text('My Company'),
                      onTap: () {
                         Navigator.pop(context); // Close the drawer first
                         Navigator.pushNamed(context, '/company/');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.format_list_bulleted),
                      title: const Text('My Events'),
                      onTap: () {
                         Navigator.pop(context); // Close the drawer first
                         Navigator.pushNamed(context, '/events/');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Calendar'),
                      onTap: () {
                         Navigator.pop(context); // Close the drawer first
                         Navigator.pushNamed(context, '/calendar/');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: const Text('Search Events'),
                      onTap: () {
                         Navigator.pop(context); // Close the drawer first
                         Navigator.pushNamed(context, '/search_events/');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Create Event'),
                      onTap: () {
                         Navigator.pop(context); // Close the drawer first
                         Navigator.pushNamed(context, '/create_event/');
                      },
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Terms & Conditions'),
                    onTap: () {
                       Navigator.pop(context); // Close the drawer first
                       Navigator.pushNamed(context, '/terms/');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Privacy Policy'),
                    onTap: () {
                       Navigator.pop(context); // Close the drawer first
                       Navigator.pushNamed(context, '/privacy/');
                    },
                  ),
                  if (kDebugMode) ...[
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Clear App Data'),
                      onTap: () async {
                        await DeveloperService.clearAppData();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('App data cleared. Restart the app.'),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}