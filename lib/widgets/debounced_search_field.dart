import 'package:flutter/material.dart';
import 'dart:async';

import 'package:crowdpass/widgets/editable_text_field.dart';

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
      return null;
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

class DebouncedSearchField<T> extends StatefulWidget {
  const DebouncedSearchField({
    super.key,
    required this.onResultSelected,
    required this.searchFunction,
    required this.getDisplayText,
    required this.tileBuilder,
    this.initialValue,
    this.decoration,
    this.isEditable = false,
    this.validator,
    this.hintText,
  });

  final Function(T? result) onResultSelected;
  final Future<Iterable<T>> Function(String query) searchFunction;
  final String Function(T result) getDisplayText;
  final Widget Function(BuildContext context, T result) tileBuilder;
  final T? initialValue;
  final InputDecoration? decoration;
  final bool isEditable;
  final String? Function(T? value)? validator;
  final String? hintText;

  @override
  State<DebouncedSearchField<T>> createState() => _DebouncedSearchFieldState<T>();
}

class _DebouncedSearchFieldState<T> extends State<DebouncedSearchField<T>> {
  final SearchController _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;
  final List<T> pastResults = <T>[];
  _DebounceTimer? _activeTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(
      (query) async => await _search(query),
      (timer) {
        _activeTimer = timer;
        if (mounted) setState(() => _isLoading = true);
        
        timer.future.whenComplete(() {
          if (mounted && _activeTimer == timer) {
            setState(() => _isLoading = false);
          }
        }).catchError((_) {
          if (mounted && _activeTimer == timer) {
            setState(() => _isLoading = false);
          }
        });
      },
    );

    if (widget.initialValue != null) {
      _searchController.text = widget.getDisplayText(widget.initialValue!);
    }
  }

  @override
  void didUpdateWidget(DebouncedSearchField<T> oldWidget) {
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

  Future<Iterable<T>> _search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return <T>[];
    try {
      return await widget.searchFunction(normalizedQuery);
    } catch (error) {
      return <T>[];
    }
  }

  void _handleSelection(T? result, FormFieldState<T> field) {
    field.didChange(result);
    widget.onResultSelected(result);
    if (result != null) {
      _searchController.text = widget.getDisplayText(result);
      if (!pastResults.contains(result)) {
        pastResults.insert(0, result);
        if (pastResults.length > 10) pastResults.removeLast();
      }
    } else {
      _searchController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: widget.initialValue,
      validator: widget.validator,
      builder: (FormFieldState<T> field) {
        return SearchAnchor(
          searchController: _searchController,
          builder: (BuildContext context, SearchController controller) {
            return EditableTextField(
              controller: controller,
              isMultiline: true,
              isEditable: widget.isEditable,
              onTap: widget.isEditable ? controller.openView : null,
              onChanged: (value) {
                if (!controller.isOpen) controller.openView();
                if (value.isEmpty) _handleSelection(null, field);
              },
              decoration: (widget.decoration ?? const InputDecoration())
                  .copyWith(
                    errorText: field.errorText,
                    labelText: widget.decoration?.labelText ?? 'Search',
                    prefixIcon:
                        widget.decoration?.prefixIcon ??
                        const Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty && widget.isEditable
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _handleSelection(null, field),
                          )
                        : null,
                  ),
            );
          },
          suggestionsBuilder: (BuildContext context, SearchController controller) async {
            if (_isLoading) {
              return const [LinearProgressIndicator()];
            }

            final Iterable<T>? results = await _debouncedSearch(controller.text);

            if (results != null && results.isNotEmpty) {
              return results.map((result) {
                return ListTile(
                  title: widget.tileBuilder(context, result),
                  onTap: () {
                    _handleSelection(result, field);
                    controller.closeView(widget.getDisplayText(result));
                  },
                );
              }).toList();
            }

            if (controller.text.isEmpty && pastResults.isNotEmpty) {
              return [
                const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Recent'),
                  dense: true,
                ),
                ...pastResults.map((result) => ListTile(
                      title: widget.tileBuilder(context, result),
                      onTap: () {
                        _handleSelection(result, field);
                        controller.closeView(widget.getDisplayText(result));
                      },
                    )),
              ];
            }

            if (controller.text.isNotEmpty) {
              return const [ListTile(title: Text('No results found'))];
            }

            return const <Widget>[];
          },
        );
      },
    );
  }
}