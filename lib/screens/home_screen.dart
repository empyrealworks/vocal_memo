// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../providers/recording_provider.dart';
import 'live_recording_screen.dart';
import '../widgets/expandable_recording_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Favorites', 'Pinned'];

  @override
  Widget build(BuildContext context) {
    final recordings = ref.watch(recordingProvider);

    List<Recording> filtered = recordings;
    if (_selectedFilter == 'Favorites') {
      filtered = recordings.where((r) => r.isFavorite).toList();
    } else if (_selectedFilter == 'Pinned') {
      filtered = recordings.where((r) => r.isPinned).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final query = _searchQuery.toLowerCase();
        return r.displayTitle.toLowerCase().contains(query) ||
            (r.transcript?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocal Memo'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          SizedBox(width: 16,)
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: SearchBar(
              onChanged: (value) => setState(() => _searchQuery = value),
              hintText: 'Search memos...',
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = filter),
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.teal,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.teal : AppTheme.mediumGray,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: () =>
                  ref.read(recordingProvider.notifier).refreshRecordings(),
              color: AppTheme.teal,
              child: ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExpandableRecordingCard(
                    recording: filtered[index],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LiveRecordingScreen()),
        ),
        child: const Icon(Icons.mic_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 64,
            color: AppTheme.teal.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the microphone to start recording',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;

  const SearchBar({
    super.key,
    required this.onChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:  TextStyle(color: AppTheme.darkText),
        prefixIcon: const Icon(Icons.search, color: AppTheme.teal),
        suffixIcon: const Icon(Icons.tune, color: AppTheme.teal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.teal, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.lightGray,
      ),
    );
  }
}
