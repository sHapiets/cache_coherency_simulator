import 'coherence_state.dart';

class CacheLine {
  int tag;
  CoherenceState state;

  CacheLine({required this.tag, required this.state});

  bool get isValid => state != CoherenceState.invalid;
}
