import 'package:flutter/material.dart';
import 'dart:async';

typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

_Debounceable<S, T> _debounce<S, T>(
  _Debounceable<S, T> function,
  void Function(_DebounceTimer) onNewTimer, {
  Duration duration = const Duration(milliseconds: 500),
}) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer(duration: duration);
    onNewTimer(debounceTimer!);
    try {
      await debounceTimer!.future;
    } catch (_) {
      return null; // Safely return null if cancelled
    }
    return function(parameter);
  };
}

class _DebounceTimer {
  _DebounceTimer({required this.duration}) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Duration duration;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() => _completer.complete();

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    if (!_completer.isCompleted) {
      _completer.completeError('Debounce cancelled');
    }
  }
}

class DebouncedSearchBar<T> extends StatefulWidget {
  const DebouncedSearchBar({
    super.key,
    required this.onResultSelected,
    required this.searchFunction,
    required this.getDisplayText,
    required this.tileBuilder,
    this.hintText,
    this.initialValue,
  });

  final Function(T result) onResultSelected;
  final Future<Iterable<T>> Function(String query) searchFunction;
  final String Function(T result) getDisplayText;
  final Widget Function(BuildContext context, T result) tileBuilder;
  final String? hintText;
  final T? initialValue;

  @override
  State<DebouncedSearchBar<T>> createState() => _DebouncedSearchBarState<T>();
}

class _DebouncedSearchBarState<T> extends State<DebouncedSearchBar<T>> {
  final SearchController _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;
  final List<T> pastResults = <T>[];
  _DebounceTimer? _activeTimer;

  // State for loading
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(
      (query) async {
        final results = await _search(query);
        return results;
      },
      (timer) {
        _activeTimer = timer;

        // Start loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = true;
            });
          }
        });

        // Stop loading on completion
        timer.future.whenComplete(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeTimer == timer) {
              setState(() {
                _isLoading = false;
              });
            }
          });
        }).catchError((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeTimer == timer) {
              setState(() {
                _isLoading = false;
              });
            }
          });
        });
      },
    );
    _searchController.text = widget.initialValue != null
        ? widget.getDisplayText(widget.initialValue!)
        : '';
  }

  @override
  void didUpdateWidget(DebouncedSearchBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _searchController.text = widget.initialValue != null
          ? widget.getDisplayText(widget.initialValue!)
          : '';
    }
  }

  @override
  void dispose() {
    _activeTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _selectResult(T result) {
    widget.onResultSelected.call(result);
    if (!pastResults.contains(result)) {
      pastResults.insert(0, result);
      if (pastResults.length > 10) {
        pastResults.removeLast();
      }
    }
  }

  Future<Iterable<T>> _search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return <T>[];

    try {
      final results = await widget.searchFunction(normalizedQuery);
      return results;
    } catch (error) {
      debugPrint('Search error: $error');
      return <T>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          onTap: controller.openView,
          leading: const Icon(Icons.search),
          hintText: widget.hintText,
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        if (_isLoading) {
          return const [
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ];
        }

        final Iterable<T>? results = await _debouncedSearch(controller.text);

        if (results != null && results.isNotEmpty) {
          return results.map((result) {
            return GestureDetector(
              onTap: () {
                _selectResult(result);
                if (controller.isOpen) {
                  controller.closeView(widget.getDisplayText(result));
                }
              },
              child: widget.tileBuilder(context, result),
            );
          }).toList();
        }

        if (controller.text.isEmpty && pastResults.isNotEmpty) {
          return <Widget>[
            const ListTile(
              leading: Icon(Icons.history),
              title: Text('Recent Searches'),
            ),
            for (final result in pastResults)
              GestureDetector(
                onTap: () {
                  _selectResult(result);
                  if (controller.isOpen) {
                    controller.closeView(widget.getDisplayText(result));
                  }
                },
                child: widget.tileBuilder(context, result),
              ),
          ];
        }

        if (controller.text.isNotEmpty) {
          return const [
            ListTile(
              title: Text('No results found'),
            ),
          ];
        }

        return const <Widget>[];
      },
    );
  }
}
