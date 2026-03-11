import 'package:flutter/material.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

class PrivacyScreen extends StatefulWidget {
  @override
  _PrivacyScreenState createState() =>
      _PrivacyScreenState();
}

class _PrivacyScreenState
    extends State<PrivacyScreen> {
  String _markdown = 'Loading terms...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTerms();
    });
  }

  Future<void> _loadTerms() async {
    try {
      String terms = await rootBundle.loadString('assets/docs/privacy.md');
      setState(() {
        _markdown = terms;
      });
    } catch (e) {
      setState(() {
        _markdown = 'Error loading terms: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Terms & Conditions'),
      ),
      body: SafeArea(
        child: Markdown(
          data: _markdown,
          padding: const EdgeInsets.all(16.0),
          styleSheet: MarkdownStyleSheet(
            h1: theme.textTheme.titleLarge,
            h2: theme.textTheme.titleMedium,
            h3: theme.textTheme.titleSmall,
            p: theme.textTheme.bodyMedium,
            a: theme.textTheme.bodyMedium?.copyWith(color: Colors.blue),
          ),
        ),
      ),
    );
  }
}
