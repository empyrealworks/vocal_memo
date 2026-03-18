import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectionProvider = StateNotifierProvider<SelectionNotifier, Set<String>>((ref) {
  return SelectionNotifier();
});

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      final newState = Set<String>.from(state);
      newState.remove(id);
      state = newState;
    } else {
      state = {...state, id};
    }
  }

  void selectAll(List<String> ids) {
    state = ids.toSet();
  }

  void clear() {
    state = {};
  }

  bool get isSelectionMode => state.isNotEmpty;
}
