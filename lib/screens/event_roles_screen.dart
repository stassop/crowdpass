import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/event_roles_provider.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/refreshable_list.dart';

class EventRolesScreen extends ConsumerStatefulWidget {
  const EventRolesScreen({super.key});

  @override
  ConsumerState<EventRolesScreen> createState() => _EventRolesScreenState();
}

class _EventRolesScreenState extends ConsumerState<EventRolesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _eventId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  void _openFilterDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
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
    final theme = Theme.of(context);

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ErrorDialog.show(
          context,
          title: 'Error loading event roles',
          message: state.error.toString(),
        );
      });
    }

    if (state.isLoading && state.event == null) {
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

    final selectedRoles = state.filters.roles;
    final anyFilterSelected = selectedRoles.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('${state.event!.title} Roles'),
        actions: [
          if (state.isOwner)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterDrawer,
              tooltip: 'Filters',
            ),
        ],
      ),
      endDrawer: state.isOwner
          ? Drawer(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Filters', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final role in EventRole.values)
                          FilterChip(
                            label: Text(role.label),
                            selected: selectedRoles.contains(role),
                            onSelected: (_) => notifier.toggleRoleFilter(role),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (anyFilterSelected)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Filters'),
                        onPressed: notifier.resetFilters,
                      ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: state.isOwner
                ? RefreshableList(
                    items: state.users,
                    hasMore: state.hasMore,
                    isLoading: state.isLoading,
                    onRefresh: notifier.refresh,
                    onLoadMore: notifier.loadMore,
                    emptyListWidget: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No users found for the selected roles.'),
                      ),
                    ),
                    tileBuilder: (context, user, index) {
                      final role = state.userToRole[user.uid];
                      final previousRole = index > 0
                          ? state.userToRole[state.users[index - 1].uid]
                          : null;
                      final showHeader = role != previousRole;

                      final tile = Dismissible(
                        key: ValueKey('${role?.name}-${user.uid}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove User Role'),
                            content: Text(
                              'Remove ${user.displayName} from the ${role?.label ?? 'selected'} role?',
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
                        onDismissed: (_) async {
                          if (role == null) return;
                          await notifier.removeUserFromRole(
                            userId: user.uid,
                            role: role,
                          );
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            foregroundImage:
                                user.photoURL != null && user.photoURL!.isNotEmpty
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null || user.photoURL!.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          trailing: state.isOwner
                              ? Text('You')
                              : null,
                          title: Text(user.displayName),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/user/',
                            arguments: user.uid,
                          ),
                        ),
                      );

                      if (!showHeader || role == null) return tile;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: theme.colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              role.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          tile,
                        ],
                      );
                    },
                  )
                : RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Only the event owner can manage event roles.',
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}