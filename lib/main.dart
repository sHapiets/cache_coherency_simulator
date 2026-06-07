import 'dart:io';

import 'package:cache_coherency_simulator/appbar_ui.dart';
import 'package:cache_coherency_simulator/core/trace_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cache_coherency_simulator/cache/cache.dart';
import 'package:cache_coherency_simulator/cache/cache_line.dart';

import 'package:cache_coherency_simulator/cache/coherence_state.dart';

import 'package:cache_coherency_simulator/core/statistics.dart';
import 'package:cache_coherency_simulator/core/delay_config.dart';

import 'package:cache_coherency_simulator/models/memory_access.dart';

void main() {
  runApp(const CacheCoherenceApp());
}

final themeModeNotifier = ValueNotifier(ThemeMode.dark);

class CacheCoherenceApp extends StatelessWidget {
  const CacheCoherenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeModeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cache Coherence Simulator',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const SimulatorPage(),
        );
      },
    );
  }
}

class AppTheme {
  static const processorPrimary = Color(0xFF2E6F80);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,

    scaffoldBackgroundColor: const Color(0xFFF7F9FB),

    colorScheme: ColorScheme.fromSeed(
      seedColor: processorPrimary,
      brightness: Brightness.light,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F9FB),
      elevation: 0,
    ),

    textTheme: ThemeData.light().textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: const Color(0xFF1E2933),
      displayColor: const Color(0xFF1E2933),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,

    scaffoldBackgroundColor: const Color(0xFF111418),

    colorScheme: ColorScheme.fromSeed(
      seedColor: processorPrimary,
      brightness: Brightness.dark,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111418),
      elevation: 0,
    ),

    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: const Color(0xFFE8EEF2),
      displayColor: const Color(0xFFE8EEF2),
    ),
  );
}

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});

  @override
  State<SimulatorPage> createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> {
  final processorsController = TextEditingController(text: '4');
  final cacheSizeController = TextEditingController(text: '8');
  final blockSizeController = TextEditingController(text: '64');

  String selectedProtocol = 'MSI';

  final cacheReadHitController = TextEditingController(text: '1');
  final cacheWriteHitController = TextEditingController(text: '1');
  final memoryReadController = TextEditingController(text: '100');
  final memoryWriteController = TextEditingController(text: '100');
  final cacheToCacheCopyController = TextEditingController(text: '20');
  final interCacheStateUpdateController = TextEditingController(text: '10');

  late DelayConfig delays;

  final Statistics stats = Statistics();

  List<String> logs = [];
  late List<Cache> caches;

  List<MemoryAccess> trace = [];

  Future<void> pickTraceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ccs'],
        withData: true,
      );

      if (result == null) {
        logs.add('File selection cancelled');

        setState(() {});

        return;
      }

      final pickedFile = result.files.single;

      String content = '';

      if (pickedFile.bytes != null) {
        content = String.fromCharCodes(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);

        content = await file.readAsString();
      } else {
        logs.add('Unable to read selected file');

        setState(() {});

        return;
      }

      trace = TraceParser.parse(content);

      setState(() {
        logs.add(
          'Loaded trace file: '
          '${pickedFile.name}',
        );

        logs.add('Parsed ${trace.length} memory accesses');
      });
    } catch (e) {
      setState(() {
        logs.add('File picker error: $e');
      });
    }
  }

  void resetStats() {
    stats.totalAccesses = 0;

    stats.reads = 0;
    stats.writes = 0;

    stats.cacheHits = 0;
    stats.cacheMisses = 0;

    stats.readHits = 0;
    stats.readMisses = 0;

    stats.writeHits = 0;
    stats.writeMisses = 0;

    stats.evictions = 0;
    stats.dirtyEvictions = 0;

    stats.memoryReads = 0;
    stats.memoryWrites = 0;

    stats.cacheToCacheTransfers = 0;

    stats.interCacheStateUpdates = 0;

    stats.totalCycles = 0;
  }

  // MAIN RUN LOOP (a.k.a the important stuff!)
  void runSimulation() {
    // initializations from input
    resetStats();

    logs.clear();

    delays = DelayConfig(
      cacheReadHit: int.parse(cacheReadHitController.text),
      cacheWriteHit: int.parse(cacheWriteHitController.text),
      memoryRead: int.parse(memoryReadController.text),
      memoryWrite: int.parse(memoryWriteController.text),
      cacheToCacheCopy: int.parse(cacheToCacheCopyController.text),
      interCacheStateUpdate: int.parse(interCacheStateUpdateController.text),
    );

    final processors = int.parse(processorsController.text);
    final cacheLines = int.parse(cacheSizeController.text);
    final blockSize = int.parse(blockSizeController.text);

    caches = List.generate(processors, (_) => Cache(cacheLines));

    // per-access loop (look for each of the
    // functions below for the implementations)
    for (final access in trace) {
      switch (selectedProtocol) {
        case 'MSI':
          simulateMSI(access, blockSize);
          break;

        case 'MESI':
          simulateMESI(access, blockSize);
          break;

        case 'MESIF':
          simulateMESIF(access, blockSize);
          break;

        case 'MOESI':
          simulateMOESI(access, blockSize);
          break;
      }
    }

    setState(() {});
  }

  /// 1: MSI
  void simulateMSI(MemoryAccess access, int blockSize) {
    final cache = caches[access.processorId];
    final line = cache.getLine(access.address, blockSize);
    final isWrite = access.type == AccessType.write;

    registerAccess(access);

    // if not INVALID, add CACHE HIT
    if (line != null && line.state != CoherenceState.invalid) {
      registerHit(access);

      // if it wants to write, set other caches to INVALID
      if (isWrite && line.state == CoherenceState.shared) {
        /// (this invalidates the other caches, except for the passed processorId)
        /// (you can find this helper after all the other protocols...)
        _invalidateOtherCaches(access.processorId, access.address, blockSize);

        line.state = CoherenceState.modified;

        registerStateUpdate();

        stats.totalCycles += delays.interCacheStateUpdate;

        logs.add('MSI: S -> M');
      }

      // add total time / cycles
      stats.totalCycles += isWrite ? delays.cacheWriteHit : delays.cacheReadHit;

      return;
    }

    // if the line.state is INVALID, it's a cache miss!
    registerMiss(access);
    registerMemoryRead();

    // add total cycles...
    stats.totalCycles += delays.memoryRead;

    // If processor also wants to write,
    ///  set all other caches to INVALID,
    ///  then set own cache line to MODIFIED
    if (isWrite) {
      _invalidateOtherCaches(access.processorId, access.address, blockSize);

      /// setLine also returns the previous state of cache line, which
      /// is used for _handleEviction (see below..)
      final evicted = cache.setLine(
        access.address,
        blockSize,
        CacheLine(
          tag: cache.getTag(access.address, blockSize),
          state: CoherenceState.modified,
        ),
      );

      /// this function adds the eviction stat counter
      /// (this helper is found below, after the protocols....)
      _handleEviction(evicted);
    }
    // If processor just wants to read,
    ///  then just set the line to SHARED
    else {
      final evicted = cache.setLine(
        access.address,
        blockSize,
        CacheLine(
          tag: cache.getTag(access.address, blockSize),
          state: CoherenceState.shared,
        ),
      );

      _handleEviction(evicted);
    }
  }

  /// 2: MESI
  void simulateMESI(MemoryAccess access, int blockSize) {
    final cache = caches[access.processorId];
    final line = cache.getLine(access.address, blockSize);
    final isWrite = access.type == AccessType.write;

    registerAccess(access);

    // Same with MSI,
    /// If the cache line state is not INVALID,
    /// then add it as a hit
    if (line != null && line.state != CoherenceState.invalid) {
      registerHit(access);

      // this switch is just to check if it
      // should invalidate the other caches
      /// (they both stay the same state, unless it wants to write -> MODIFIED)
      switch (line.state) {
        // if the prev state is SHARED, it should set
        // the others to INVALID
        case CoherenceState.shared:
          if (isWrite) {
            _invalidateOtherCaches(
              access.processorId,
              access.address,
              blockSize,
            );

            line.state = CoherenceState.modified;
            registerStateUpdate();

            stats.totalCycles += delays.interCacheStateUpdate;

            logs.add('MESI: S -> M');
          }

          break;

        // But, if the prev state is EXCLUSIVE
        /// no need for any INVALID set
        case CoherenceState.exclusive:
          if (isWrite) {
            line.state = CoherenceState.modified;

            logs.add('MESI: E -> M');
          }

          break;

        default:
          break;
      }

      stats.totalCycles += isWrite ? delays.cacheWriteHit : delays.cacheReadHit;

      return;
    }

    // If INVALID....
    registerMiss(access);

    /// 1. Determine if the AT LEAST ONE of the other caches
    ///    has a copy (any of E, S, or M)
    final hasSharers = _otherCachesHaveCopy(
      access.processorId,
      access.address,
      blockSize,
    );

    /// 2. If there is, switch them to SHARED
    if (hasSharers && !isWrite) {
      _downgradeMESISharers(access.processorId, access.address, blockSize);
    }

    registerMemoryRead();
    stats.totalCycles += delays.memoryRead;

    // Same as MSI,
    /// If processor wants to write,
    /// set the rest to INVALID, then set this line to MODIFIED
    if (isWrite) {
      _invalidateOtherCaches(access.processorId, access.address, blockSize);

      final evicted = cache.setLine(
        access.address,
        blockSize,
        CacheLine(
          tag: cache.getTag(access.address, blockSize),
          state: CoherenceState.modified,
        ),
      );

      _handleEviction(evicted);
    }
    // If proc just wants to read,
    /// set the line to either EXCLUSIVE or SHARED,
    /// (dependent on the hasSharers evaluation earlier...)
    else {
      final evicted = cache.setLine(
        access.address,
        blockSize,
        CacheLine(
          tag: cache.getTag(access.address, blockSize),
          state: hasSharers ? CoherenceState.shared : CoherenceState.exclusive,
        ),
      );

      _handleEviction(evicted);
    }
  }

  // 3: MESIF
  void simulateMESIF(MemoryAccess access, int blockSize) {
    final cache = caches[access.processorId];
    final line = cache.getLine(access.address, blockSize);
    final isWrite = access.type == AccessType.write;

    registerAccess(access);

    // Same as the first two,
    /// A non-INVALID state means its a hit
    if (line != null && line.state != CoherenceState.invalid) {
      registerHit(access);

      //
      switch (line.state) {
        // If the prev state is S/F,
        /// change to MODIFY,
        /// but set the other caches to INVALID too
        case CoherenceState.shared:
        case CoherenceState.forward:
          if (isWrite) {
            _invalidateOtherCaches(
              access.processorId,
              access.address,
              blockSize,
            );

            line.state = CoherenceState.modified;

            registerStateUpdate();

            stats.totalCycles += delays.interCacheStateUpdate;

            logs.add('MESIF: S/F -> M');
          }

          break;

        /// If exclusive, no need to invalidate other caches
        case CoherenceState.exclusive:
          if (isWrite) {
            line.state = CoherenceState.modified;

            logs.add('MESIF: E -> M');
          }

          break;

        default:
          break;
      }

      /// add total cycles...
      stats.totalCycles += isWrite ? delays.cacheWriteHit : delays.cacheReadHit;

      return;
    }

    // If INVALID....
    registerMiss(access);

    /// 1: get all other caches that are not INVALID (meaning has a copy)
    final sharers = _getSharers(access.processorId, access.address, blockSize);

    /// 2A: No sharers = MEMORY DELAY
    if (sharers.isEmpty) {
      registerMemoryRead();
      stats.totalCycles += delays.memoryRead;
    }
    /// 2B: Someone has a 'copy' = ONLY CACHE DELAY
    /// (a FORWARD should exist)
    else {
      registerCacheTransfer();
      stats.totalCycles += delays.cacheToCacheCopy;
    }

    // 3A: Same as MSI/MESI,
    /// If proc wants to write, set others to INVALID
    if (isWrite) {
      _invalidateOtherCaches(access.processorId, access.address, blockSize);

      final evicted = cache.setLine(
        access.address,
        blockSize,
        CacheLine(
          tag: cache.getTag(access.address, blockSize),
          state: CoherenceState.modified,
        ),
      );

      _handleEviction(evicted);
    }
    // 3B: If it just wants to read...
    else {
      /// Like MESI, no sharers mean EXCLUSIVE state
      if (sharers.isEmpty) {
        final evicted = cache.setLine(
          access.address,
          blockSize,
          CacheLine(
            tag: cache.getTag(access.address, blockSize),
            state: CoherenceState.exclusive,
          ),
        );

        _handleEviction(evicted);
      }
      /// If there are other sharers....
      else {
        /// Check if one of them is a forwarder first....

        /// (flag)
        bool alreadyHasForwarder = false;

        for (final sharer in sharers) {
          final otherLine = caches[sharer].getLine(access.address, blockSize);

          if (otherLine == null) continue;

          if (otherLine.state == CoherenceState.forward) {
            alreadyHasForwarder = true;
          }

          switch (otherLine.state) {
            case CoherenceState.modified:
              otherLine.state = CoherenceState.forward;

              alreadyHasForwarder = true;

              break;

            case CoherenceState.exclusive:
              otherLine.state = CoherenceState.forward;

              alreadyHasForwarder = true;

              break;

            default:
              break;
          }
        }

        /// If NONE of the sharers is FORWARD,
        /// then, just set the first one as the FORWARD....
        if (!alreadyHasForwarder && sharers.isNotEmpty) {
          final first = caches[sharers.first].getLine(
            access.address,
            blockSize,
          );

          if (first != null) {
            first.state = CoherenceState.forward;
          }
        }

        /// And always set this one to shared
        final evicted = cache.setLine(
          access.address,
          blockSize,
          CacheLine(
            tag: cache.getTag(access.address, blockSize),
            state: CoherenceState.shared,
          ),
        );

        _handleEviction(evicted);
      }
    }
  }

  // 4: MOESI
  void simulateMOESI(MemoryAccess access, int blockSize) {
    final cache = caches[access.processorId];
    final line = cache.getLine(access.address, blockSize);
    final isWrite = access.type == AccessType.write;

    registerAccess(access);

    // Same as the others,
    /// Non-invalid = cache-hit
    if (line != null && line.state != CoherenceState.invalid) {
      registerHit(access);

      switch (line.state) {
        // Same as the others,
        /// If proc wants to write =
        /// invalidate other caches unless EXCLUSIVE
        case CoherenceState.shared:
          if (isWrite) {
            _invalidateOtherCaches(
              access.processorId,
              access.address,
              blockSize,
            );

            line.state = CoherenceState.modified;

            registerStateUpdate();

            stats.totalCycles += delays.interCacheStateUpdate;

            logs.add('MOESI: S -> M');
          }

          break;

        case CoherenceState.owned:
          if (isWrite) {
            _invalidateOtherCaches(
              access.processorId,
              access.address,
              blockSize,
            );

            line.state = CoherenceState.modified;

            registerStateUpdate();

            stats.totalCycles += delays.interCacheStateUpdate;

            logs.add('MOESI: O -> M');
          }

          break;

        case CoherenceState.exclusive:
          if (isWrite) {
            line.state = CoherenceState.modified;

            logs.add('MOESI: E -> M');
          }

          break;

        default:
          break;
      }

      stats.totalCycles += isWrite ? delays.cacheWriteHit : delays.cacheReadHit;

      return;
    }

    /// If INVALID..
    registerMiss(access);

    /// 1: Find the cache whose line is OWNER
    //// (but technically, either OWNED or MODIFIED, details explained in helper...)
    final owner = _findOwner(access.processorId, access.address, blockSize);

    /// Same functionality as MESIF,
    //// instead of forward, an OWNER in any of the other processors
    //// is a cache direct transfer
    if (owner != null) {
      registerCacheTransfer();

      stats.totalCycles += delays.cacheToCacheCopy;
    } else {
      registerMemoryRead();

      stats.totalCycles += delays.memoryRead;
    }

    /// If it wants to write, invalidate other caches
    if (isWrite) {
      _invalidateOtherCaches(access.processorId, access.address, blockSize);

      final evicted = cache.setLine(
        access.address,
        blockSize,
        CacheLine(
          tag: cache.getTag(access.address, blockSize),
          state: CoherenceState.modified,
        ),
      );

      _handleEviction(evicted);
    }
    /// If it just wants to read...
    else {
      if (owner != null) {
        final ownerLine = caches[owner].getLine(access.address, blockSize);

        if (ownerLine != null) {
          switch (ownerLine.state) {
            /// set the MODIFIED to
            case CoherenceState.modified:
              ownerLine.state = CoherenceState.owned;
              break;

            case CoherenceState.exclusive:
              ownerLine.state = CoherenceState.shared;
              break;

            default:
              break;
          }
        }

        final evicted = cache.setLine(
          access.address,
          blockSize,
          CacheLine(
            tag: cache.getTag(access.address, blockSize),
            state: CoherenceState.shared,
          ),
        );

        _handleEviction(evicted);
      } else {
        final evicted = cache.setLine(
          access.address,
          blockSize,
          CacheLine(
            tag: cache.getTag(access.address, blockSize),
            state: CoherenceState.exclusive,
          ),
        );

        _handleEviction(evicted);
      }
    }
  }

  /// HELPERS
  /// Some of helpers are only used for adding to the stats,
  /// specifically functions that are explicitly named
  /// 'register____'
  ///
  /// The rest are helpers found earlier, which
  /// you could see the actual implementation.

  void registerAccess(MemoryAccess access) {
    stats.totalAccesses++;

    if (access.type == AccessType.read) {
      stats.reads++;
    } else {
      stats.writes++;
    }
  }

  void registerHit(MemoryAccess access) {
    stats.cacheHits++;

    if (access.type == AccessType.read) {
      stats.readHits++;
    } else {
      stats.writeHits++;
    }
  }

  void registerMiss(MemoryAccess access) {
    stats.cacheMisses++;

    if (access.type == AccessType.read) {
      stats.readMisses++;
    } else {
      stats.writeMisses++;
    }
  }

  void registerMemoryRead() {
    stats.memoryReads++;
  }

  void registerMemoryWrite() {
    stats.memoryWrites++;
  }

  void registerCacheTransfer() {
    stats.cacheToCacheTransfers++;
  }

  void registerStateUpdate() {
    stats.interCacheStateUpdates++;
  }

  void registerEviction({required bool dirty}) {
    stats.evictions++;

    if (dirty) {
      stats.dirtyEvictions++;

      stats.memoryWrites++;
    }
  }

  /// Just checks if
  /// 1: Tag is the same from the line address (since direct-mapped)
  /// 2: Not invalid
  bool _otherCachesHaveCopy(int requester, int address, int blockSize) {
    for (int i = 0; i < caches.length; i++) {
      if (i == requester) continue;

      // note: getLine returns null
      // if the tag of the passed address is different
      final line = caches[i].getLine(address, blockSize);

      if (line != null && line.state != CoherenceState.invalid) {
        return true;
      }
    }

    return false;
  }

  /// Gets an actual list of the caches with copies
  /// of the given address
  /// (only used by MESIF for forwarding)
  List<int> _getSharers(int requester, int address, int blockSize) {
    List<int> sharers = [];

    for (int i = 0; i < caches.length; i++) {
      if (i == requester) continue;

      final line = caches[i].getLine(address, blockSize);

      //
      if (line != null &&
          (line.state != CoherenceState.invalid &&
              line.state != CoherenceState.modified)) {
        sharers.add(i);
      }
    }

    return sharers;
  }

  /// Finds the OWNER
  /// (only used by MOESI)
  int? _findOwner(int requester, int address, int blockSize) {
    for (int i = 0; i < caches.length; i++) {
      if (i == requester) continue;

      final line = caches[i].getLine(address, blockSize);

      if (line != null &&
          (line.state == CoherenceState.owned ||
              line.state == CoherenceState.modified)) {
        return i;
      }
    }

    return null;
  }

  /// Whenever
  void _invalidateOtherCaches(int requester, int address, int blockSize) {
    for (int i = 0; i < caches.length; i++) {
      if (i == requester) continue;

      final line = caches[i].getLine(address, blockSize);

      if (line == null) continue;

      if (line.state != CoherenceState.invalid) {
        final dirty =
            line.state == CoherenceState.modified ||
            line.state == CoherenceState.owned;

        if (dirty) {
          registerMemoryWrite();

          stats.totalCycles += delays.memoryWrite;

          logs.add('Writeback from P$i');
        }

        line.state = CoherenceState.invalid;

        registerStateUpdate();

        stats.totalCycles += delays.interCacheStateUpdate;

        logs.add('Invalidate P$i');
      }
    }
  }

  void _handleEviction(CacheLine? evicted) {
    if (evicted == null) {
      debugPrint("awit");
      return;
    }

    if (evicted.state == CoherenceState.invalid) {
      debugPrint("awit1");
      return;
    }

    final dirty =
        evicted.state == CoherenceState.modified ||
        evicted.state == CoherenceState.owned;

    registerEviction(dirty: dirty);

    if (dirty) {
      stats.totalCycles += delays.memoryWrite;

      logs.add('Dirty eviction writeback');
    }
  }

  void _downgradeMESISharers(int requester, int address, int blockSize) {
    for (int i = 0; i < caches.length; i++) {
      if (i == requester) continue;

      final line = caches[i].getLine(address, blockSize);

      if (line == null) continue;

      switch (line.state) {
        case CoherenceState.modified:
          registerMemoryWrite();

          stats.totalCycles += delays.memoryWrite;

          line.state = CoherenceState.shared;

          break;

        case CoherenceState.exclusive:
          line.state = CoherenceState.shared;

          break;

        default:
          break;
      }
    }
  }

  //////// THIS IS UI STUFF ///////////

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),

      child: Align(
        alignment: Alignment.centerLeft,

        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget spacedField(Widget child) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: child);
  }

  Widget statTile(
    String label,
    dynamic value,
    IconData icon,
    Color color,
    ThemeData themeData,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(
        color: themeData.colorScheme.surface,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: color.withOpacity(0.25)),
      ),

      child: Row(
        children: [
          Icon(icon, color: color, size: 18),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: themeData.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),

          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: themeData.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  final ScrollController _controllerStats = ScrollController();

  Widget buildStatsPane({required ThemeData themeData}) {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      controller: _controllerStats,
      child: SingleChildScrollView(
        controller: _controllerStats,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            statsCategoryTitle('Overall', Icons.analytics, themeData),

            statTile(
              'Total Accesses',
              stats.totalAccesses,
              Icons.memory,
              Colors.blue,
              themeData,
            ),

            statTile(
              'Reads',
              stats.reads,
              Icons.download,
              Colors.green,
              themeData,
            ),

            statTile(
              'Writes',
              stats.writes,
              Icons.upload,
              Colors.orange,
              themeData,
            ),
            const SizedBox(height: 12),

            statsCategoryTitle('Runtime', Icons.timer, themeData),

            statTile(
              'Total Cycles',
              stats.totalCycles,
              Icons.timer,
              Colors.pink,
              themeData,
            ),

            const SizedBox(height: 12),

            statsCategoryTitle('Cache Analysis', Icons.speed, themeData),

            statTile(
              'Cache Hits',
              stats.cacheHits,
              Icons.check_circle,
              Colors.teal,
              themeData,
            ),

            statTile(
              'Cache Misses',
              stats.cacheMisses,
              Icons.error,
              Colors.red,
              themeData,
            ),

            statTile(
              'Read Hits',
              stats.readHits,
              Icons.download_done,
              Colors.lightGreen,
              themeData,
            ),

            statTile(
              'Read Misses',
              stats.readMisses,
              Icons.download_for_offline,
              Colors.deepOrange,
              themeData,
            ),

            statTile(
              'Write Hits',
              stats.writeHits,
              Icons.upload_file,
              Colors.cyan,
              themeData,
            ),

            statTile(
              'Write Misses',
              stats.writeMisses,
              Icons.file_upload_off,
              Colors.pinkAccent,
              themeData,
            ),

            const SizedBox(height: 12),

            statsCategoryTitle('Memory Traffic', Icons.storage, themeData),

            statTile(
              'Memory Reads',
              stats.memoryReads,
              Icons.move_down,
              Colors.purple,
              themeData,
            ),

            statTile(
              'Memory Writes',
              stats.memoryWrites,
              Icons.move_up,
              Colors.deepPurpleAccent,
              themeData,
            ),

            statTile(
              'Cache Transfers',
              stats.cacheToCacheTransfers,
              Icons.swap_horiz,
              Colors.amber,
              themeData,
            ),

            const SizedBox(height: 12),

            statsCategoryTitle('Coherence Events', Icons.sync, themeData),

            statTile(
              'State Updates',
              stats.interCacheStateUpdates,
              Icons.sync,
              Colors.cyan,
              themeData,
            ),

            const SizedBox(height: 12),

            statsCategoryTitle('Evictions', Icons.delete_outline, themeData),

            statTile(
              'Evictions',
              stats.evictions,
              Icons.delete,
              Colors.orangeAccent,
              themeData,
            ),

            statTile(
              'Dirty Evictions',
              stats.dirtyEvictions,
              Icons.warning_amber,
              Colors.redAccent,
              themeData,
            ),
          ],
        ),
      ),
    );
  }

  Widget statsCategoryTitle(String title, IconData icon, ThemeData themeData) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),

      child: Row(
        children: [
          Icon(icon, size: 18, color: themeData.colorScheme.primary),

          const SizedBox(width: 8),

          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: themeData.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildExecutionPane({required ThemeData themeData}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,

                child: ElevatedButton.icon(
                  onPressed: pickTraceFile,

                  icon: Icon(
                    Icons.upload_file,
                    size: 18,
                    color: themeData.colorScheme.onPrimary,
                  ),

                  label: Text(
                    'Load Trace [.ccs]',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: themeData.colorScheme.onPrimary,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeData.colorScheme.primary,

                    foregroundColor: themeData.colorScheme.onPrimary,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                    side: BorderSide(color: themeData.colorScheme.primary),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: SizedBox(
                height: 42,

                child: ElevatedButton.icon(
                  onPressed: runSimulation,

                  icon: Icon(
                    Icons.play_arrow,
                    size: 18,
                    color: themeData.colorScheme.onSecondary,
                  ),

                  label: Text(
                    'Run Trace',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: themeData.colorScheme.onSecondary,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeData.colorScheme.secondary,

                    foregroundColor: themeData.colorScheme.onSecondary,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                    side: BorderSide(color: themeData.colorScheme.secondary),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Icon(
              Icons.terminal,
              size: 18,
              color: themeData.colorScheme.onSurface,
            ),

            const SizedBox(width: 8),

            Text(
              'Log',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: themeData.colorScheme.surface,

              borderRadius: BorderRadius.circular(12),

              border: Border.all(
                color: themeData.colorScheme.outline.withOpacity(0.4),
              ),
            ),

            child: SingleChildScrollView(
              child: SelectableText(
                logs.join('\n'),

                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                  color: themeData.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  final ScrollController _controllerConfig = ScrollController();

  Widget buildConfigPane() {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      controller: _controllerConfig,
      child: SingleChildScrollView(
        controller: _controllerConfig,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            sectionTitle('System'),

            spacedField(
              TextField(
                controller: processorsController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Processors',

                  prefixIcon: Icon(Icons.memory),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: cacheSizeController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Cache Lines',

                  prefixIcon: Icon(Icons.storage),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: blockSizeController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Block Size',

                  prefixIcon: Icon(Icons.grid_view),
                ),
              ),
            ),

            const SizedBox(height: 10),

            sectionTitle('Protocol'),

            spacedField(
              DropdownButtonFormField<String>(
                value: selectedProtocol,

                decoration: const InputDecoration(
                  isDense: true,

                  prefixIcon: Icon(Icons.settings),
                ),

                items: const [
                  DropdownMenuItem(value: 'MSI', child: Text('MSI')),

                  DropdownMenuItem(value: 'MESI', child: Text('MESI')),

                  DropdownMenuItem(value: 'MESIF', child: Text('MESIF')),

                  DropdownMenuItem(value: 'MOESI', child: Text('MOESI')),
                ],

                onChanged: (value) {
                  setState(() {
                    selectedProtocol = value!;
                  });
                },
              ),
            ),

            const SizedBox(height: 10),

            sectionTitle('Delay Cycles'),

            spacedField(
              TextField(
                controller: cacheReadHitController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Cache Read Hit',

                  prefixIcon: Icon(Icons.download),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: cacheWriteHitController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Cache Write Hit',

                  prefixIcon: Icon(Icons.upload),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: memoryReadController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Memory Read',

                  prefixIcon: Icon(Icons.storage),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: memoryWriteController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Memory Write',

                  prefixIcon: Icon(Icons.save),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: cacheToCacheCopyController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Cache-to-Cache Transfer',

                  prefixIcon: Icon(Icons.swap_horiz),
                ),
              ),
            ),

            spacedField(
              TextField(
                controller: interCacheStateUpdateController,

                decoration: const InputDecoration(
                  isDense: true,

                  labelText: 'Inter-cache State Update',

                  prefixIcon: Icon(Icons.sync),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPane({
    required String title,
    required Widget child,
    required ThemeData themeData,
  }) {
    return Container(
      margin: const EdgeInsets.all(30),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: themeData.colorScheme.surface,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: themeData.colorScheme.primary),

        boxShadow: [
          BoxShadow(
            color: themeData.shadowColor.withOpacity(0.2),
            offset: const Offset(10, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeData.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 10),

          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarUI(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1100) {
            return ListView(
              children: [
                SizedBox(
                  height: 700,

                  child: buildPane(
                    title: 'Configuration',

                    child: buildConfigPane(),
                    themeData: Theme.of(context),
                  ),
                ),

                SizedBox(
                  height: 450,

                  child: buildPane(
                    title: 'Simulation',

                    child: buildExecutionPane(themeData: Theme.of(context)),

                    themeData: Theme.of(context),
                  ),
                ),

                SizedBox(
                  height: 650,

                  child: buildPane(
                    title: 'Statistics',

                    child: buildStatsPane(themeData: Theme.of(context)),

                    themeData: Theme.of(context),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Flexible(
                flex: 3,

                child: buildPane(
                  title: 'Configuration',
                  child: buildConfigPane(),
                  themeData: Theme.of(context),
                ),
              ),

              Flexible(
                flex: 4,

                child: buildPane(
                  title: 'Simulation',

                  child: buildExecutionPane(themeData: Theme.of(context)),

                  themeData: Theme.of(context),
                ),
              ),

              Flexible(
                flex: 3,

                child: buildPane(
                  title: 'Statistics',

                  child: buildStatsPane(themeData: Theme.of(context)),

                  themeData: Theme.of(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
