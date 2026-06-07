enum AccessType { read, write }

class MemoryAccess {
  final int processorId;
  final AccessType type;
  final int address;

  MemoryAccess({
    required this.processorId,
    required this.type,
    required this.address,
  });
}
