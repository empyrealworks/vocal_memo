// lib/screens/onboarding_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Onboarding page data ─────────────────────────────────────────────────────

class _OnboardingPage {
  final String imagePath; // asset path  e.g. 'assets/images/onboarding_1.png'
  final IconData fallbackIcon; // shown if image asset is missing
  final String title;
  final String subtitle;
  final Color accentColor;

  const _OnboardingPage({
    required this.imagePath,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}

const _pages = [
  _OnboardingPage(
    imagePath: 'assets/images/onboarding_record.png',
    fallbackIcon: Icons.mic_rounded,
    title: 'Record Instantly',
    subtitle:
    'Capture ideas, notes, and conversations at any moment — no typing needed.',
    accentColor: AppTheme.teal,
  ),
  _OnboardingPage(
    imagePath: 'assets/images/onboarding_transcribe.png',
    fallbackIcon: Icons.text_fields_rounded,
    title: 'AI Transcription',
    subtitle:
    'Turn speech into searchable text in seconds, powered by Gemini AI.',
    accentColor: AppTheme.orange,
  ),
  _OnboardingPage(
    imagePath: 'assets/images/onboarding_organize.png',
    fallbackIcon: Icons.folder_special_rounded,
    title: 'Stay Organized',
    subtitle:
    'Tag, pin, and search everything. Find any memo in an instant.',
    accentColor: AppTheme.teal,
  ),
  _OnboardingPage(
    imagePath: 'assets/images/onboarding_sync.png',
    fallbackIcon: Icons.cloud_done_rounded,
    title: 'Secure Cloud Backup',
    subtitle:
    'Your recordings are encrypted and safely backed up. Access them from any device.',
    accentColor: AppTheme.orange,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _fadeController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page) async {
    await _fadeController.reverse();
    _pageController.jumpToPage(page);
    await _fadeController.forward();
  }

  Future<void> _next() async {
    if (_currentPage < _pages.length - 1) {
      await _goToPage(_currentPage + 1);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _fadeController.forward(from: 0);
                },
                itemBuilder: (context, i) {
                  return FadeTransition(
                    opacity: _fadeController,
                    child: _PageContent(page: _pages[i]),
                  );
                },
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return GestureDetector(
                        onTap: () => _goToPage(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 28 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? page.accentColor
                                : AppTheme.mediumGray,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // Primary action button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: page.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _next,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual page ──────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;

  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image or fallback icon
          _buildHero(context),
          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).hintColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    // Try to load the asset image; fall back to an icon if the file isn't
    // bundled yet (so the screen works before the user adds their images).
    return _AssetImageOrIcon(
      assetPath: page.imagePath,
      fallbackIcon: page.fallbackIcon,
      accentColor: page.accentColor,
    );
  }
}

// ─── Conditional asset image ──────────────────────────────────────────────────

class _AssetImageOrIcon extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final Color accentColor;

  const _AssetImageOrIcon({
    required this.assetPath,
    required this.fallbackIcon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: 260,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _buildIconFallback(),
    );
  }

  Widget _buildIconFallback() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(fallbackIcon, size: 60, color: accentColor),
        ),
      ),
    );
  }
}