import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/user_profile.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/event_roles_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/refreshable_list.dart';
import 'package:crowdpass/widgets/animated_dialog.dart';
import 'package:crowdpass/widgets/user_avatar.dart';

class EventRolesScreen extends ConsumerStatefulWidget {
  const EventRolesScreen({super.key});

  @override
  ConsumerState<EventRolesScreen> createState() => _EventRolesScreenState();
}

class _EventRolesScreenState extends ConsumerState<EventRolesScreen>
    with SingleTickerProviderStateMixin {
  String? _eventId;
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventId ??= ModalRoute.of(context)?.settings.arguments as String?;
    _tabController ??= TabController(length: EventRole.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _showRoleDialog(UserProfile user) async {
    await AnimatedDialog.show(
      context: context,
      content: Consumer(
        builder: (context, ref, child) {
          final notifier = ref.read(eventRolesProvider(_eventId!).notifier);
          final userRoleAsync = ref.watch(
            userRoleProvider((eventId: _eventId!, userId: user.uid)),
          );

          return userRoleAsync.when(
            loading: () => const Center(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Center(
              child: Text('Error loading user role: $error'),
            ),
            data: (selectedRole) {
              final currentUser = ref.watch(authProvider).value;
              // Rules for editing roles:
              // - Owners role can't be changed or removed
              // - Admins can add or change other roles, including their own
              // - Non-admins can't edit roles
              final canEdit = selectedRole != EventRole.owner &&
                  (selectedRole == EventRole.admin || currentUser?.uid != user.uid);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UserAvatar.medium(
                    displayName: user.displayName, 
                    photoURL: user.photoURL,
                    onTap: () => Navigator.of(context).pushNamed('/user/', arguments: user.uid)
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<EventRole>(
                    value: selectedRole,
                    items: [
                      for (final role in EventRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                    ],
                    onChanged: canEdit
                        ? (newRole) async {
                            if (newRole == null || newRole == selectedRole) return;
                            await notifier.addUserToRole(userId: user.uid, role: newRole);
                            if (context.mounted && Navigator.canPop(context)) {
                              Navigator.of(context).pop();
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_eventId == null || _eventId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Event Roles'),
        ),
        body: const Center(child: Text('Missing event id.')),
      );
    }

    final state = ref.watch(eventRolesProvider(_eventId!));
    final notifier = ref.read(eventRolesProvider(_eventId!).notifier);
    final hasRole = ref
        .watch(
          userRoleProvider((
            eventId: _eventId!,
            userId: ref.watch(authProvider).value?.uid,
          )),
        )
        .maybeWhen(data: (role) => role != null, orElse: () => false);

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ErrorDialog.show(
          context,
          title: 'Error loading event roles',
          message: state.error.toString(),
        );
      });
    }

    if (!hasRole) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Event Roles'),
        ),
        body: const Center(
          child: Text('You do not have permission to view this event\'s roles.'),
        ),
      );
    }

    final isInitialLoading =
        state.event == null && EventRole.values.any(state.isLoadingRole);

    if (isInitialLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Event Roles'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.event == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Event Not Found'),
        ),
        body: const Center(
          child: Text('The specified event could not be found.'),
        ),
      );
    }

    return DefaultTabController(
      length: EventRole.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${state.event!.title} Roles'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              for (final role in EventRole.values)
                Tab(text: role.collectionLabel),
            ],
          )
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            for (final role in EventRole.values)
              _RoleTab(
                role: role,
                users: state.usersForRole(role),
                isLoading: state.isLoadingRole(role),
                hasMore: state.hasMoreForRole(role),
                onRefresh: () => notifier.loadMore(role, replace: true),
                onLoadMore: () => notifier.loadMore(role),
                onRemoveUser: (userId) => notifier.removeUserFromRole(
                  userId: userId,
                  role: role,
                ),
                onUserTap: (user) => _showRoleDialog(user),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.role,
    required this.users,
    required this.isLoading,
    required this.hasMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRemoveUser,
    required this.onUserTap,
  });

  final EventRole role;
  final List<UserProfile> users;
  final bool isLoading;
  final bool hasMore;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(String userId) onRemoveUser;
  final void Function(UserProfile user) onUserTap;

  @override
  Widget build(BuildContext context) {
    return RefreshableList<UserProfile>(
      items: users,
      hasMore: hasMore,
      isLoading: isLoading,
      onRefresh: onRefresh,
      onLoadMore: onLoadMore,
      emptyListWidget: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No users found for the ${role.label.toLowerCase()} role.'),
        ),
      ),
      tileBuilder: (context, user, index) {
        final tile = ListTile(
          leading: CircleAvatar(
            foregroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null || user.photoURL!.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(user.displayName),
          onTap: () => onUserTap(user),
        );

        // Owner can't be removed from their role
        if (role == EventRole.owner) {
          return tile;
        }

        return Dismissible(
          key: ValueKey('${role.name}-${user.uid}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove User Role'),
              content: Text(
                'Remove ${user.displayName} from the ${role.label} role?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
          onDismissed: (_) => onRemoveUser(user.uid),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: tile,
        );
      },
    );
  }
}