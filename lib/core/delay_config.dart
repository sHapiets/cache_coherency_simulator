class DelayConfig {
  final int cacheReadHit;
  final int cacheWriteHit;
  final int memoryRead;
  final int memoryWrite;
  final int cacheToCacheCopy;
  final int interCacheStateUpdate;

  DelayConfig({
    required this.cacheReadHit,
    required this.cacheWriteHit,
    required this.memoryRead,
    required this.memoryWrite,
    required this.cacheToCacheCopy,
    required this.interCacheStateUpdate,
  });

  factory DelayConfig.defaultConfig() {
    return DelayConfig(
      cacheReadHit: 1,
      cacheWriteHit: 1,
      memoryRead: 100,
      memoryWrite: 100,
      cacheToCacheCopy: 20,
      interCacheStateUpdate: 10,
    );
  }
}
