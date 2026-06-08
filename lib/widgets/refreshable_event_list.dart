import 'package:flutter/material.dart';
import 'package:crowdpass/models/event.dart';
import 'package:intl/intl.dart';

/// Helper wrapper to preserve the original global index for the itemBuilder
class IndexedEvent {
  final int globalIndex;
  final Event event;
  IndexedEvent(this.globalIndex, this.event);
}

class RefreshableEventList extends StatefulWidget {
  final List<Event> events;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final Widget Function(BuildContext context, Event event, int index) itemBuilder;
  final Widget? emptyListWidget;
  final Widget? loadingIndicatorWidget;

  const RefreshableEventList({
    super.key,
    required this.events,
    required this.onRefresh,
    required this.itemBuilder,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.emptyListWidget,
    this.loadingIndicatorWidget,
  });

  @override
  State<RefreshableEventList> createState() => _RefreshableEventListState();
}

class _RefreshableEventListState extends State<RefreshableEventList> {
  final ScrollController _scrollController = ScrollController();
  bool _isPerformingLoadMore = false;

  static const double _stickyHeaderHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  /// Sorts and groups events by year and month
  Map<DateTime, List<IndexedEvent>> get _groupedEvents {
    final sorted = List<Event>.from(widget.events)
      ..sort((a, b) => a.dates.start.compareTo(b.dates.start));

    final Map<DateTime, List<IndexedEvent>> groups = {};
    
    for (int i = 0; i < sorted.length; i++) {
      final event = sorted[i];
      final start = event.dates.start;
      final monthKey = DateTime(start.year, start.month);
      
      groups.putIfAbsent(monthKey, () => []).add(IndexedEvent(i, event));
    }
    
    return groups;
  }

  Future<void> _onScroll() async {
    if (!_scrollController.hasClients || _isPerformingLoadMore) return;

    const double scrollThreshold = 200.0;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= scrollThreshold &&
        widget.onLoadMore != null &&
        widget.hasMore &&
        !widget.isLoading) {
      _isPerformingLoadMore = true;
      try {
        await widget.onLoadMore!();
      } finally {
        _isPerformingLoadMore = false;
      }
    }
  }

  Widget _buildMonthHeader(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat.yMMMM(locale).format(date);

    return Container(
      height: _stickyHeaderHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.primaryContainer,
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupedEvents;
    final bool showBottomLoadingIndicator = grouped.isNotEmpty && widget.isLoading && widget.hasMore;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (grouped.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
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
            )
          else
            ...grouped.entries.map((entry) {
              final month = entry.key;
              final indexedEvents = entry.value;

              // This is where the magic happens
              return SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyMonthHeaderDelegate(
                      height: _stickyHeaderHeight,
                      child: _buildMonthHeader(context, month),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final indexedEvent = indexedEvents[index];
                        return widget.itemBuilder(
                          ctx, 
                          indexedEvent.event, 
                          indexedEvent.globalIndex,
                        );
                      },
                      childCount: indexedEvents.length,
                    ),
                  ),
                ],
              );
            }),
          if (showBottomLoadingIndicator)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: widget.loadingIndicatorWidget ?? const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _StickyMonthHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyMonthHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}