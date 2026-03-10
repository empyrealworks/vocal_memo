// lib/widgets/feature_gate_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/auth_screen.dart';

/// Reusable dialog for features behind registration/subscription wall
class FeatureGateDialog extends StatelessWidget {
  final String title;
  final String message;
  final List<String> benefits;
  final bool requiresSubscription;

  const FeatureGateDialog({
    super.key,
    required this.title,
    required this.message,
    this.benefits = const [],
    this.requiresSubscription = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: requiresSubscription
                    ? AppTheme.orange.withValues(alpha: 0.1)
                    : AppTheme.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                requiresSubscription ? Icons.diamond : Icons.lock_open,
                size: 32,
                color: requiresSubscription ? AppTheme.orange : AppTheme.teal,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            // Benefits list
            if (benefits.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: benefits
                      .map(
                        (benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppTheme.teal, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.mediumGray),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      if (!requiresSubscription) {
                        // Navigate to auth screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                            const AuthScreen(showBenefits: true),
                          ),
                        );
                      } else {
                        // TODO: Navigate to subscription screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Subscription coming soon!'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: requiresSubscription
                          ? AppTheme.orange
                          : AppTheme.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      requiresSubscription ? 'Upgrade' : 'Sign Up',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show the dialog and return true if user wants to proceed (navigate to auth)
  static Future<bool> show(
      BuildContext context, {
        required String title,
        required String message,
        List<String> benefits = const [],
        bool requiresSubscription = false,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FeatureGateDialog(
        title: title,
        message: message,
        benefits: benefits,
        requiresSubscription: requiresSubscription,
      ),
    );
    return result ?? false;
  }
}