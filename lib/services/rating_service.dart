import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

class RatingService {
  static final InAppReview _review = InAppReview.instance;

  static Future<void> requestReview() async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview(); // In-app dialog if available
      } else {
        // Fallback to Play Store page
        await _review.openStoreListing(
          appStoreId: 'com.empyrealworks.vocal_memo',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error launching review: $e");
      }
    }
  }
}
