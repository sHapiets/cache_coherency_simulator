import 'package:cache_coherency_simulator/cache/coherence_state.dart';

import 'cache_line.dart';

class Cache {
  final int numLines;

  late List<CacheLine?> lines;

  Cache(this.numLines) {
    lines = List.filled(numLines, null);
  }

  int getIndex(int address, int blockSize) {
    return (address ~/ blockSize) % numLines;
  }

  int getTag(int address, int blockSize) {
    return (address ~/ blockSize) ~/ numLines;
  }

  CoherenceState? getCoherenceState(int address, int blockSize) {
    final index = getIndex(address, blockSize);

    final line = lines[index];

    if (line == null) return null;

    return line.state;
  }

  CacheLine? getLine(int address, int blockSize) {
    final index = getIndex(address, blockSize);

    final line = lines[index];

    if (line == null) return null;

    final tag = getTag(address, blockSize);

    if (line.tag != tag) return null;

    return line;
  }

  CacheLine? setLine(int address, int blockSize, CacheLine newLine) {
    final index = getIndex(address, blockSize);

    final current = lines[index];

    CacheLine? evicted;

    if (current != null) {
      final tag = current.tag;
      final state = current.state;
      evicted = CacheLine(tag: tag, state: state);
    }

    lines[index] = newLine;

    return evicted;
  }
}
