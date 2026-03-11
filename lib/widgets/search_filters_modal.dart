// lib/widgets/search_filters_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SearchFilters {
  final Duration? minDuration;
  final Duration? maxDuration;
  final bool searchTranscripts;
  final DateTime? fromDate;
  final DateTime? toDate;

  SearchFilters({
    this.minDuration,
    this.maxDuration,
    this.searchTranscripts = false,
    this.fromDate,
    this.toDate,
  });

  SearchFilters copyWith({
    Duration? minDuration,
    Duration? maxDuration,
    bool? searchTranscripts,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return SearchFilters(
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      searchTranscripts: searchTranscripts ?? this.searchTranscripts,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  bool get hasActiveFilters =>
      minDuration != null ||
          maxDuration != null ||
          searchTranscripts ||
          fromDate != null ||
          toDate != null;
}

class SearchFiltersModal extends ConsumerStatefulWidget {
  final SearchFilters initialFilters;

  const SearchFiltersModal({
    super.key,
    required this.initialFilters,
  });

  @override
  ConsumerState<SearchFiltersModal> createState() =>
      _SearchFiltersModalState();
}

class _SearchFiltersModalState extends ConsumerState<SearchFiltersModal> {
  late SearchFilters _filters;

  final List<Duration> _durationPresets = [
    const Duration(seconds: 30),
    const Duration(minutes: 1),
    const Duration(minutes: 5),
    const Duration(minutes: 10),
    const Duration(minutes: 30),
    const Duration(hours: 1),
  ];

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authStateProvider).value != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Filters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filters = SearchFilters();
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recording Length
          Text(
            'Recording Length',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durationPresets.map((duration) {
              final isMinSelected = _filters.minDuration == duration;
              final isMaxSelected = _filters.maxDuration == duration;

              return ChoiceChip(
                label: Text(_formatDuration(duration)),
                selected: isMinSelected || isMaxSelected,
                onSelected: (selected) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(_formatDuration(duration)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('Minimum'),
                            leading: Radio<bool>(
                              value: true,
                              groupValue: isMinSelected,
                              onChanged: (val) {
                                setState(() {
                                  _filters = _filters.copyWith(
                                    minDuration: duration,
                                  );
                                });
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          ListTile(
                            title: const Text('Maximum'),
                            leading: Radio<bool>(
                              value: true,
                              groupValue: isMaxSelected,
                              onChanged: (val) {
                                setState(() {
                                  _filters = _filters.copyWith(
                                    maxDuration: duration,
                                  );
                                });
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                selectedColor: AppTheme.teal,
                backgroundColor: Theme.of(context).cardColor,
                side: BorderSide(color: AppTheme.mediumGray),
              );
            }).toList(),
          ),

          if (_filters.minDuration != null || _filters.maxDuration != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Length: ${_filters.minDuration != null ? "${_formatDuration(_filters.minDuration!)} - " : ""}${_filters.maxDuration != null ? _formatDuration(_filters.maxDuration!) : "Any"}',
                style: const TextStyle(fontSize: 12, color: AppTheme.teal),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Search Transcripts (Registered users only)
          SwitchListTile(
            title: const Text('Search Transcripts'),
            subtitle: isAuthenticated
                ? const Text('Include transcript text in search')
                : const Text('Available for registered users only'),
            value: _filters.searchTranscripts && isAuthenticated,
            onChanged: isAuthenticated
                ? (value) {
              setState(() {
                _filters = _filters.copyWith(searchTranscripts: value);
              });
            }
                : null,
            activeThumbColor: AppTheme.teal,
          ),

          const SizedBox(height: 16),

          // Date Range
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.mediumGray, width: 2),
                  ),
                  label: Text(
                    _filters.fromDate != null
                        ? _formatDate(_filters.fromDate!)
                        : 'From',
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _filters.fromDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _filters = _filters.copyWith(fromDate: date);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.mediumGray, width: 2),
                  ),
                  label: Text(
                    _filters.toDate != null
                        ? _formatDate(_filters.toDate!)
                        : 'To',
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _filters.toDate ?? DateTime.now(),
                      firstDate: _filters.fromDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _filters = _filters.copyWith(toDate: date);
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _filters),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}