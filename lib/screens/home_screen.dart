// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/providers/selection_provider.dart';
import 'package:vocal_memo/widgets/search_filters_modal.dart';
import 'package:vocal_memo/widgets/selection_bar.dart';
import '../services/storage_service.dart';
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
  SearchFilters _searchFilters = SearchFilters();

  // Tutorial
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _firstCardKey = GlobalKey();
  bool _showTutorial = false;
  int _tutorialStep = 0; // 0 = FAB, 1 = first card

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final seen = StorageService.getHomeTutorialSeen();
    if (!seen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showTutorial = true);
      });
    }
  }

  Future<void> _advanceTutorial() async {
    final recordings = ref.read(recordingProvider);
    if (_tutorialStep == 0 && recordings.isNotEmpty) {
      setState(() => _tutorialStep = 1);
    } else {
      await _dismissTutorial();
    }
  }

  Future<void> _dismissTutorial() async {
    setState(() => _showTutorial = false);
    await StorageService.setHomeTutorialSeen(true);
  }

  @override
  Widget build(BuildContext context) {
    final recordings = ref.watch(recordingProvider);
    final selectedIds = ref.watch(selectionProvider);
    final selectionModeActive = selectedIds.isNotEmpty;

    List<Recording> filtered = recordings;

    // Apply category filter
    if (_selectedFilter == 'Favorites') {
      filtered = recordings.where((r) => r.isFavorite).toList();
    } else if (_selectedFilter == 'Pinned') {
      filtered = recordings.where((r) => r.isPinned).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = r.displayTitle.toLowerCase().contains(query);
        final transcriptMatch = _searchFilters.searchTranscripts &&
            r.transcript != null &&
            r.transcript!.toLowerCase().contains(query);
        return titleMatch || transcriptMatch;
      }).toList();
    }

    // Apply advanced filters
    if (_searchFilters.hasActiveFilters) {
      filtered = filtered.where((r) {
        if (_searchFilters.minDuration != null &&
            r.duration < _searchFilters.minDuration!) {
          return false;
        }
        if (_searchFilters.maxDuration != null &&
            r.duration > _searchFilters.maxDuration!) {
          return false;
        }

        if (_searchFilters.fromDate != null) {
          final fromDate = DateTime(
            _searchFilters.fromDate!.year,
            _searchFilters.fromDate!.month,
            _searchFilters.fromDate!.day,
          );
          if (r.createdAt.isBefore(fromDate)) {
            return false;
          }
        }
        if (_searchFilters.toDate != null) {
          final toDate = DateTime(
            _searchFilters.toDate!.year,
            _searchFilters.toDate!.month,
            _searchFilters.toDate!.day,
            23,
            59,
            59,
          );
          if (r.createdAt.isAfter(toDate)) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    return PopScope(
      canPop: !selectionModeActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectionModeActive) {
          ref.read(selectionProvider.notifier).clear();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: selectionModeActive
                  ? Text('${selectedIds.length} selected')
                  : Row(
                      children: [
                        Image.asset('assets/images/small_logo.png', width: 24,),
                        const SizedBox(width: 15,),
                        const Text('Vocal Memo', style: TextStyle(fontSize: 22),)
                      ],
                    ),
              elevation: 0,
              leading: selectionModeActive
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => ref.read(selectionProvider.notifier).clear(),
                    )
                  : null,
              actions: [
                if (!selectionModeActive)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                const SizedBox(width: 16,)
              ],
            ),
            body: Column(
              children: [
                if (!selectionModeActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                    child: SearchBar(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      hintText: 'Search memos...',
                      onFilterTap: () async {
                        final result = await showModalBottomSheet<SearchFilters>(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => SearchFiltersModal(
                            initialFilters: _searchFilters,
                          ),
                        );
                        if (result != null) {
                          setState(() => _searchFilters = result);
                        }
                      },
                      hasActiveFilters: _searchFilters.hasActiveFilters,
                    ),
                  ),
                if (!selectionModeActive)
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
                        child: index == 0
                            ? KeyedSubtree(
                          key: _firstCardKey,
                          child: ExpandableRecordingCard(
                            recording: filtered[index],
                          ),
                        )
                            : ExpandableRecordingCard(
                          recording: filtered[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: selectionModeActive
                ? null
                : FloatingActionButton(
                    key: _fabKey,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LiveRecordingScreen()),
                    ),
                    child: const Icon(Icons.mic_rounded),
                  ),
            bottomNavigationBar: const SelectionBar(),
          ),

          if (_showTutorial && !selectionModeActive)
            _TutorialOverlay(
              step: _tutorialStep,
              targetKey: _tutorialStep == 0 ? _fabKey : _firstCardKey,
              onNext: _advanceTutorial,
              onDismiss: _dismissTutorial,
              hasRecordings: recordings.isNotEmpty,
            ),
        ],
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

// ─── Tutorial overlay ─────────────────────────────────────────────────────────

class _TutorialOverlay extends StatefulWidget {
  final int step;
  final GlobalKey targetKey;
  final VoidCallback onNext;
  final VoidCallback onDismiss;
  final bool hasRecordings;

  const _TutorialOverlay({
    required this.step,
    required this.targetKey,
    required this.onNext,
    required this.onDismiss,
    required this.hasRecordings,
  });

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ));
    _measureTarget();
  }

  @override
  void didUpdateWidget(_TutorialOverlay old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) _measureTarget();
  }

  void _measureTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = widget.targetKey.currentContext;
      if (ctx == null || !mounted) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final offset = box.localToGlobal(Offset.zero);
      setState(() {
        _targetRect = offset & box.size;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static const _steps = [
    _TutorialStepData(
      title: 'Start recording',
      description:
      'Tap the mic button to begin capturing a new voice memo.',
      tooltipBelow: false,
    ),
    _TutorialStepData(
      title: 'Expand a recording',
      description:
      'Tap any card to expand it and access trim ✂️, AI transcription 📝, cloud backup ☁️, share, and more.',
      tooltipBelow: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    final stepData = _steps[widget.step.clamp(0, _steps.length - 1)];
    final totalSteps = widget.hasRecordings ? 2 : 1;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (rect != null)
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _SpotlightPainter(targetRect: rect),
            )
          else
            Container(color: Colors.black54),

          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.teal,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (rect != null)
            _buildTooltip(context, rect, stepData, totalSteps),
        ],
      ),
    );
  }

  Widget _buildTooltip(
      BuildContext context,
      Rect targetRect,
      _TutorialStepData stepData,
      int totalSteps,
      ) {
    const cardWidth = 280.0;
    const padding = 16.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double left = (screenWidth - cardWidth) / 2;
    left = left.clamp(padding, screenWidth - cardWidth - padding);

    final double top;
    if (stepData.tooltipBelow) {
      top = (targetRect.bottom + 16).clamp(padding, screenHeight - 180);
    } else {
      top = (targetRect.top - 160).clamp(padding, screenHeight - 180);
    }

    return Positioned(
      left: left,
      top: top,
      width: cardWidth,
      child: GestureDetector(
        onTap: () {},
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.step + 1} / $totalSteps',
                        style: const TextStyle(
                          color: AppTheme.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(Icons.close,
                          size: 18, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  stepData.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  stepData.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    if (widget.step < totalSteps - 1)
                      TextButton(
                        onPressed: widget.onDismiss,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.step < totalSteps - 1 ? 'Next →' : 'Got it!',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStepData {
  final String title;
  final String description;
  final bool tooltipBelow;

  const _TutorialStepData({
    required this.title,
    required this.description,
    required this.tooltipBelow,
  });
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;

  const _SpotlightPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    final spotlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          targetRect.inflate(6),
          const Radius.circular(14),
        ),
      );

    final backgroundPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      spotlightPath,
    );

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawPath(backgroundPath, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.targetRect != targetRect;
}



class SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback onFilterTap;
  final bool hasActiveFilters;

  const SearchBar({
    super.key,
    required this.onChanged,
    required this.hintText,
    required this.onFilterTap,
    this.hasActiveFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppTheme.darkText),
        prefixIcon: const Icon(Icons.search, color: AppTheme.teal),
        suffixIcon: IconButton(
          icon: Badge(
            isLabelVisible: hasActiveFilters,
            backgroundColor: AppTheme.orange,
            child: const Icon(Icons.tune, color: AppTheme.teal),
          ),
          onPressed: onFilterTap,
        ),
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
        fillColor: Theme.of(context).canvasColor,
      ),
    );
  }
}