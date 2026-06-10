import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/event_roles_provider.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EventRolesScreen extends ConsumerStatefulWidget {
  const EventRolesScreen({super.key});

  @override
  ConsumerState<EventRolesScreen> createState() => _EventRolesScreenState();
}

class _EventRolesScreenState extends ConsumerState<EventRolesScreen> {
  String? _eventId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  Future<void> _showAddUserDialog(
    BuildContext context,
    EventRolesNotifier notifier,
  ) async {
    final userIdController = TextEditingController();
    EventRole selectedRole = EventRole.staff;

    final result = await showDialog<(String, EventRole)>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add User Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EventRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                    ),
                    items: EventRole.values
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final userId = userIdController.text.trim();
                    if (userId.isEmpty) return;
                    Navigator.pop(context, (userId, selectedRole));
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await notifier.addUserToRole(
        userId: result.$1,
        role: result.$2,
      );
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
        body: const Center(
          child: Text('Missing event id.'),
        ),
      );
    }

    final state = ref.watch(eventRolesProvider(_eventId!));
    final notifier = ref.read(eventRolesProvider(_eventId!).notifier);

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

    return Scaffold(
      appBar: AppBar(
        title: Text('${state.event!.title} Roles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: state.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showAddUserDialog(context, notifier),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Role'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: const Text('My Role'),
                subtitle: Text(state.currentUserRole?.label ?? 'No role found'),
              ),
            ),
            const SizedBox(height: 16),
            if (state.isOwner) ...[
              Text(
                'All Roles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final role in EventRole.values)
                Card(
                  child: ExpansionTile(
                    title: Text(role.label),
                    subtitle: Text(
                      '${state.roleToUserIds[role]?.length ?? 0} user(s)',
                    ),
                    children: [
                      if ((state.roleToUserIds[role] ?? []).isEmpty)
                        const ListTile(
                          title: Text('No users assigned'),
                        ),
                      for (final userId in state.roleToUserIds[role] ?? [])
                        ListTile(
                          title: Text(userId),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            tooltip: 'Remove',
                            onPressed: () => notifier.removeUserFromRole(
                              userId: userId,
                              role: role,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}