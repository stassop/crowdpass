import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/drawer_menu.dart';

class HomeScreen extends StatelessWidget {
	const HomeScreen({Key? key}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		return Scaffold(
			backgroundColor: theme.primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'CrowdPass',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () => Navigator.pushNamed(context, '/create_event/'),
				label: const Text('Create Event'),
				tooltip: 'Create Event',
				icon: const Icon(Icons.add),
			),
			drawer: const DrawerMenu(),
			body: Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						Text(
							'Crowd\nPass',
							style: theme.textTheme.displayLarge?.copyWith(
								color: Colors.white,
								fontWeight: FontWeight.bold,
							),
							textAlign: TextAlign.center,
						),
						const SizedBox(height: 24),
						Text(
							'Be There!',
							style: theme.textTheme.headlineSmall?.copyWith(
								color: Colors.white70,
								fontWeight: FontWeight.w500,
							),
							textAlign: TextAlign.center,
						),
						const SizedBox(height: 48),
						ElevatedButton.icon(
							onPressed: () => Navigator.pushNamed(context, '/search/'),
							icon: const Icon(Icons.search),
							label: const Text('Search Events'),
						),
					],
				),
			),
		);
	}
}
