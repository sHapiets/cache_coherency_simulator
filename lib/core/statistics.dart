class Statistics {
  int totalAccesses = 0;

  int reads = 0;
  int writes = 0;

  int cacheHits = 0;
  int cacheMisses = 0;

  int readHits = 0;
  int readMisses = 0;

  int writeHits = 0;
  int writeMisses = 0;

  int evictions = 0;
  int dirtyEvictions = 0;

  int memoryReads = 0;
  int memoryWrites = 0;

  int cacheToCacheTransfers = 0;
  int interCacheStateUpdates = 0;

  int totalCycles = 0;
}
