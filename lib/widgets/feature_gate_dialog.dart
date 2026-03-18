// lib/widgets/feature_gate_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/auth_screen.dart';
import 'custom_dialog.dart';

/// Reusable logic for features behind registration/subscription wall using CustomDialog
class FeatureGateDialog {
  /// Show the dialog and return true if user wants to proceed (navigate to auth)
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    List<String> benefits = const [],
    bool requiresSubscription = false,
  }) async {
    return await CustomDialog.show(
      context,
      icon: requiresSubscription ? Icons.diamond : Icons.lock_open,
      iconColor: requiresSubscription ? AppTheme.orange : AppTheme.teal,
      title: title,
      message: message,
      confirmText: requiresSubscription ? 'Upgrade' : 'Sign Up',
      confirmColor: requiresSubscription ? AppTheme.orange : AppTheme.teal,
      content: benefits.isNotEmpty
          ? Container(
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
            )
          : null,
      onConfirm: () {
        if (!requiresSubscription) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AuthScreen(showBenefits: true),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription coming soon!'),
            ),
          );
        }
      },
    );
  }
}
