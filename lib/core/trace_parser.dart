import '../models/memory_access.dart';

class TraceParser {
  static List<MemoryAccess> parse(String content) {
    final lines = content.split('\n');

    List<MemoryAccess> accesses = [];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(' ');

      final processorId = int.parse(parts[0].substring(1));

      final type = parts[1] == 'R' ? AccessType.read : AccessType.write;

      final address = int.parse(parts[2]);

      accesses.add(
        MemoryAccess(processorId: processorId, type: type, address: address),
      );
    }

    return accesses;
  }
}
