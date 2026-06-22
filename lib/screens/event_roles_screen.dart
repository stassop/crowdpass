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

    if (_eventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _eventId == null) return;
        ref.read(eventRolesProvider(_eventId!).notifier).refresh();
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _showRoleDialog(UserProfile user) async {
    final selectedRole = await AnimatedDialog.show<EventRole?>(
      context: context,
      content: Consumer(
        builder: (context, ref, child) {
          final userRoleAsync = ref.watch(
            userRoleProvider((eventId: _eventId!, userId: user.uid)),
          );

          return userRoleAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => Center(
              child: Text('Error loading user role: $error'),
            ),
            data: (userRole) {
              final currentUserRole = ref.watch(
                userRoleProvider((
                  eventId: _eventId!,
                  userId: ref.watch(authProvider).value?.uid,
                )),
              ).maybeWhen(data: (role) => role, orElse: () => null);

              final canEdit =
                  userRole != EventRole.owner || currentUserRole == EventRole.admin;
              EventRole? pendingRole = userRole;

              return StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      UserAvatar.medium(
                        displayName: user.displayName,
                        photoURL: user.photoURL,
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed('/user/', arguments: user.uid),
                      ),
                      const SizedBox(height: 16),
                      DropdownMenu<EventRole>(
                        initialSelection: userRole,
                        enabled: canEdit,
                        onSelected: (newRole) {
                          if (newRole == null) return;
                          setState(() {
                            pendingRole = newRole;
                          });
                        },
                        dropdownMenuEntries: [
                          for (final role in EventRole.values)
                            DropdownMenuEntry<EventRole>(
                              value: role,
                              label: role.label,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: canEdit
                                ? () => Navigator.of(context).pop(pendingRole)
                                : null,
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );

    if (!mounted || selectedRole == null) return;

    final notifier = ref.read(eventRolesProvider(_eventId!).notifier);
    final currentRole = await ref.read(
      userRoleProvider((eventId: _eventId!, userId: user.uid)).future,
    );

    if (selectedRole != currentRole) {
      await notifier.addUserToRole(userId: user.uid, role: selectedRole);
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text('${state.event!.title} Roles'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final role in EventRole.values)
              Tab(text: role.collectionLabel),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final role in EventRole.values)
            _RoleTab(
              eventId: _eventId!,
              role: role,
              onUserTap: (user) => _showRoleDialog(user),
            ),
        ],
      ),
    );
  }
}

class _RoleTab extends ConsumerStatefulWidget {
  const _RoleTab({
    required this.eventId,
    required this.role,
    required this.onUserTap,
  });

  final String eventId;
  final EventRole role;
  final void Function(UserProfile user) onUserTap;

  @override
  ConsumerState<_RoleTab> createState() => _RoleTabState();
}

class _RoleTabState extends ConsumerState<_RoleTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(eventRolesProvider(widget.eventId));
      if (state.usersForRole(widget.role).isEmpty && !state.isLoadingRole(widget.role)) {
        ref.read(eventRolesProvider(widget.eventId).notifier).loadMore(widget.role, replace: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventRolesProvider(widget.eventId));
    final notifier = ref.read(eventRolesProvider(widget.eventId).notifier);

    final users = state.usersForRole(widget.role);
    final isLoading = state.isLoadingRole(widget.role);
    final hasMore = state.hasMoreForRole(widget.role);

    return RefreshableList<UserProfile>(
      items: users,
      hasMore: hasMore,
      isLoading: isLoading,
      onRefresh: () => notifier.loadMore(widget.role, replace: true),
      onLoadMore: () => notifier.loadMore(widget.role),
      emptyListWidget: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No users found for the ${widget.role.label.toLowerCase()} role.'),
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
          onTap: () => widget.onUserTap(user),
        );

        if (widget.role == EventRole.owner) {
          return tile;
        }

        final dismissibleColor = Theme.of(context).colorScheme.onError;

        return Dismissible(
          key: ValueKey('${widget.role.name}-${user.uid}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove User Role'),
              content: Text(
                'Remove ${user.displayName} from the ${widget.role.label} role?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: dismissibleColor,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
          onDismissed: (_) => notifier.removeUserFromRole(
            userId: user.uid,
            role: widget.role,
          ),
          background: Container(
            color: dismissibleColor,
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