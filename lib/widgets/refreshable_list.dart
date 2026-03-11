import 'package:flutter/material.dart';

class RefreshableList<T> extends StatefulWidget {
  final bool hasMore;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) tileBuilder;
  final Widget? emptyListWidget;
  final Widget? loadingIndicatorWidget;

  const RefreshableList({
    super.key,
    required this.onRefresh,
    required this.items,
    required this.tileBuilder,
    this.hasMore = false,
    this.isLoading = false,
    this.onLoadMore,
    this.emptyListWidget,
    this.loadingIndicatorWidget,
  });

  @override
  State<RefreshableList<T>> createState() => _RefreshableListState<T>();
}

class _RefreshableListState<T> extends State<RefreshableList<T>> {
  final ScrollController _scrollController = ScrollController();

  // A local flag to prevent multiple concurrent load more calls
  // This helps avoid issues if onScroll is triggered rapidly.
  bool _isPerformingLoadMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _onScroll() async {
    // Only proceed if the scroll controller has clients and we're not already loading more
    if (!_scrollController.hasClients || _isPerformingLoadMore) {
      return;
    }

    // Define a threshold for when to trigger onLoadMore.
    // This value determines how close to the end of the scroll
    // the user needs to be before more items are loaded.
    const double scrollThreshold = 200.0;

    // Calculate how far the user has scrolled from the top and
    // the maximum scroll extent (the total height of the scrollable content).
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.position.pixels;

    // Check if the user is near the end of the scrollable content,
    // if there's an `onLoadMore` function provided,
    // if there are more items to load, and if we're not currently loading.
    if (maxScroll - currentScroll <= scrollThreshold &&
        widget.onLoadMore != null &&
        widget.hasMore &&
        !widget.isLoading) {
      // Set the flag to true to prevent re-triggering while loading.
      _isPerformingLoadMore = true;
      try {
        // Execute the `onLoadMore` function provided by the parent widget.
        await widget.onLoadMore!();
      } finally {
        // Ensure the flag is reset to false after loading, regardless of success or failure.
        _isPerformingLoadMore = false;
      }
    }
  }

  @override
  void dispose() {
    // It's crucial to remove the listener and dispose the controller
    // to prevent memory leaks.
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine if the loading indicator should be shown at the bottom for "load more"
    // This should only happen if there are items, we're currently loading, and there's more to load.
    final bool showBottomLoadingIndicator =
        widget.items.isNotEmpty && widget.isLoading && widget.hasMore;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: widget.items.isEmpty
          ? ListView(
              controller: _scrollController,
              // AlwaysScrollableScrollPhysics allows the RefreshIndicator to work
              // even if the list content is not long enough to scroll.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: widget.isLoading
                        ? (widget.loadingIndicatorWidget ?? const CircularProgressIndicator())
                        : (widget.emptyListWidget ??
                            Text(
                              'No items found',
                              style: theme.textTheme.titleMedium,
                            )),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              // Adjust item count to include the loading indicator at the bottom if needed.
              itemCount: widget.items.length + (showBottomLoadingIndicator ? 1 : 0),
              itemBuilder: (context, index) {
                // If we are at the last index and the bottom loading indicator should be shown,
                // return the loading widget.
                if (index == widget.items.length && showBottomLoadingIndicator) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: widget.loadingIndicatorWidget ?? const CircularProgressIndicator(),
                    ),
                  );
                }
                // Otherwise, return the regular item tile.
                final item = widget.items[index];
                return widget.tileBuilder(context, item, index);
              },
            ),
    );
  }
}