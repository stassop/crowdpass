import 'package:flutter/material.dart';

class PaginatedStepView extends StatefulWidget {
  final List<Widget> pages;
  final Future<bool> Function(int index) onValidatePage;
  final VoidCallback onFinish;
  final bool isLoading;
  final String submitLabel;

  const PaginatedStepView({
    Key? key,
    required this.pages,
    required this.onValidatePage,
    required this.onFinish,
    this.isLoading = false,
    this.submitLabel = 'Submit',
  }) : super(key: key);

  @override
  State<PaginatedStepView> createState() => _PaginatedStepViewState();
}

class _PaginatedStepViewState extends State<PaginatedStepView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToNextPage() async {
    final isValid = await widget.onValidatePage(_currentPage);
    if (isValid) {
      if (_currentPage < widget.pages.length - 1) {
        _pageController.animateToPage(
          _currentPage + 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        widget.onFinish();
      }
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: widget.pages,
          ),
        ),
        // Pagination Controls
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.pages.length, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 20 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primaryContainer,
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.isLoading || _currentPage == 0
                          ? null
                          : _goToPreviousPage,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.isLoading ? null : _goToNextPage,
                      icon: Icon(
                        _currentPage < widget.pages.length - 1
                            ? Icons.arrow_forward
                            : Icons.check,
                      ),
                      label: Text(
                        _currentPage < widget.pages.length - 1
                            ? 'Next'
                            : widget.submitLabel,
                      ),
                      iconAlignment: _currentPage < widget.pages.length - 1
                          ? IconAlignment.end
                          : IconAlignment.start,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}