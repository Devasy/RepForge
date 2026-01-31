# Workout Sharing Feature

## Overview

Enable users to export and import routines, workout templates, and achievements via QR codes, deep links, or file sharing. This allows knowledge transfer between users and backup capabilities.

## User Stories

1. **As a user**, I want to share my routine with a friend via QR code.
2. **As a user**, I want to import a routine someone shared with me.
3. **As a user**, I want to export my workout data for backup.
4. **As a user**, I want to share my PR achievements on social media.
5. **As a user**, I want to browse and import community-shared routines.

## Sharing Methods

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **QR Code** | In-person sharing | Quick, visual | Requires camera |
| **Deep Link** | Online sharing | Works everywhere | Needs URL handling |
| **File Export** | Backup/Transfer | Complete data | Manual process |
| **Cloud Sync** | Multi-device | Automatic | Requires account |

## Data Model

### Shareable Content Model

```dart
class ShareableContent {
  final String id;
  final ShareableType type;
  final String version;                  // App version for compatibility
  final DateTime createdAt;
  final String? creatorName;             // Optional attribution
  final dynamic content;                 // Routine, Workout, etc.
  final String checksum;                 // Integrity verification
  
  ShareableContent({
    required this.id,
    required this.type,
    required this.version,
    required this.createdAt,
    this.creatorName,
    required this.content,
    required this.checksum,
  });
  
  String toJson() => jsonEncode(toMap());
  
  String toBase64() => base64Encode(utf8.encode(toJson()));
  
  static ShareableContent fromBase64(String encoded) {
    final json = utf8.decode(base64Decode(encoded));
    return ShareableContent.fromJson(json);
  }
}

enum ShareableType {
  routine,           // Single routine
  routineBundle,     // Multiple routines
  workout,           // Single workout session
  exercise,          // Custom exercise
  fullBackup,        // All user data
  prAchievement,     // PR celebration share
}
```

### Share Link Format

```
repforge://share/{type}/{encodedData}

Examples:
repforge://share/routine/eyJpZCI6InIxMjMiLCJuYW1lIjoiUHVzaCBEYXki...
repforge://share/pr/eyJleGVyY2lzZSI6IkJlbmNoIFByZXNzIiwidmFsdWUi...
```

### QR Code Payload

```json
{
  "app": "repforge",
  "version": "1.0.0",
  "type": "routine",
  "data": {
    "id": "r123",
    "name": "Push Day",
    "exercises": ["bench_press", "incline_db", "shoulder_press"],
    "createdBy": "John",
    "description": "My push day routine"
  },
  "checksum": "abc123"
}
```

## UI/UX Design

### 1. Share Routine Screen

```
┌─────────────────────────────────────┐
│  Share "Push Day"                   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │       [QR CODE IMAGE]       │    │
│  │                             │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  Scan this code or share link       │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🔗 Copy Link                │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 📤 Share via...             │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 💾 Export as File           │    │
│  └─────────────────────────────┘    │
│                                     │
│  Include with share:                │
│  ☑ Exercise order                   │
│  ☑ Rest times                       │
│  ☐ My personal notes                │
│  ☐ My set/rep recommendations       │
│                                     │
└─────────────────────────────────────┘
```

### 2. Import Routine Screen

```
┌─────────────────────────────────────┐
│  Import Routine                     │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 📷 Scan QR Code             │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 🔗 Paste Link               │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 📁 Import from File         │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 3. Import Preview

```
┌─────────────────────────────────────┐
│  Import Preview                     │
├─────────────────────────────────────┤
│                                     │
│  "Push Day" by John                 │
│  ────────────────────────────────   │
│                                     │
│  5 Exercises:                       │
│  1. Bench Press                     │
│  2. Incline Dumbbell Press          │
│  3. Shoulder Press                  │
│  4. Lateral Raises                  │
│  5. Tricep Pushdowns                │
│                                     │
│  ⚠️ 1 custom exercise included      │
│     "Cable Crossover" will be       │
│     added to your library           │
│                                     │
│  ┌─────────────────────────────┐    │
│  │       IMPORT ROUTINE        │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Cancel]                           │
│                                     │
└─────────────────────────────────────┘
```

### 4. Share PR Achievement

```
┌─────────────────────────────────────┐
│  Share Your PR! 🏆                  │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │   🏆 NEW PERSONAL RECORD    │    │
│  │                             │    │
│  │      BENCH PRESS            │    │
│  │      100kg × 5              │    │
│  │                             │    │
│  │   Estimated 1RM: 116kg      │    │
│  │                             │    │
│  │   ━━━━━━━━━━━━━━━━━━━━━━   │    │
│  │   repforge.app              │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  [📷 Save Image]  [📤 Share]        │
│                                     │
└─────────────────────────────────────┘
```

### 5. QR Scanner

```
┌─────────────────────────────────────┐
│  Scan Routine QR Code               │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │    ┌─────────────────┐      │    │
│  │    │                 │      │    │
│  │    │   📷 CAMERA     │      │    │
│  │    │     FEED        │      │    │
│  │    │                 │      │    │
│  │    └─────────────────┘      │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  Point camera at QR code            │
│                                     │
│  [🔦 Toggle Flash]                  │
│  [📁 Select from Gallery]           │
│                                     │
└─────────────────────────────────────┘
```

## Implementation Details

### Share Service

```dart
class ShareService {
  final QRGenerator _qrGenerator;
  final DeepLinkHandler _deepLinkHandler;
  
  /// Generate shareable content for a routine
  ShareableContent createRoutineShare(Routine routine, {
    bool includeRestTimes = true,
    bool includeNotes = false,
    String? creatorName,
  }) {
    final content = {
      'routine': routine.toMap(),
      'includeRestTimes': includeRestTimes,
      'customExercises': _getCustomExercisesForRoutine(routine),
    };
    
    return ShareableContent(
      id: const Uuid().v4(),
      type: ShareableType.routine,
      version: AppVersion.current,
      createdAt: DateTime.now(),
      creatorName: creatorName,
      content: content,
      checksum: _generateChecksum(content),
    );
  }
  
  /// Generate QR code image
  Future<Uint8List> generateQRCode(ShareableContent content) async {
    final data = content.toBase64();
    return _qrGenerator.generate(data, size: 300);
  }
  
  /// Generate share link
  String generateShareLink(ShareableContent content) {
    final encoded = content.toBase64();
    return 'https://repforge.app/share/${content.type.name}/$encoded';
  }
  
  /// Parse incoming share
  Future<ShareableContent?> parseShareData(String data) async {
    try {
      // Handle deep link
      if (data.startsWith('repforge://') || data.startsWith('https://repforge.app/')) {
        return _parseDeepLink(data);
      }
      // Handle raw base64
      return ShareableContent.fromBase64(data);
    } catch (e) {
      return null;
    }
  }
  
  /// Import routine from share
  Future<ImportResult> importRoutine(ShareableContent content) async {
    // Validate version compatibility
    if (!_isVersionCompatible(content.version)) {
      return ImportResult.failure('Incompatible version');
    }
    
    // Validate checksum
    if (!_validateChecksum(content)) {
      return ImportResult.failure('Data corrupted');
    }
    
    // Import custom exercises first
    final customExercises = content.content['customExercises'] as List?;
    if (customExercises != null) {
      for (var ex in customExercises) {
        await _importCustomExercise(ex);
      }
    }
    
    // Import routine
    final routine = Routine.fromMap(content.content['routine']);
    await _workoutProvider.createRoutine(routine.name, routine.exerciseIds);
    
    return ImportResult.success(routine);
  }
}
```

### Deep Link Handler

```dart
class DeepLinkHandler {
  StreamSubscription? _linkSubscription;
  
  void init() {
    // Handle app opened from link
    getInitialLink().then(_handleDeepLink);
    
    // Handle link while app is running
    _linkSubscription = linkStream.listen(_handleDeepLink);
  }
  
  void _handleDeepLink(String? link) {
    if (link == null) return;
    
    final uri = Uri.parse(link);
    if (uri.host == 'share' || uri.pathSegments.first == 'share') {
      final type = uri.pathSegments[1];
      final data = uri.pathSegments[2];
      
      // Navigate to import preview
      NavigationService.navigateTo(
        '/import-preview',
        arguments: {'type': type, 'data': data},
      );
    }
  }
  
  void dispose() {
    _linkSubscription?.cancel();
  }
}
```

### Export/Backup Service

```dart
class BackupService {
  /// Export all user data
  Future<File> exportFullBackup() async {
    final data = {
      'version': AppVersion.current,
      'exportedAt': DateTime.now().toIso8601String(),
      'routines': await _exportRoutines(),
      'sessions': await _exportSessions(),
      'customExercises': await _exportCustomExercises(),
      'personalRecords': await _exportPRs(),
      'settings': await _exportSettings(),
    };
    
    final json = jsonEncode(data);
    final compressed = gzip.encode(utf8.encode(json));
    
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/repforge_backup_${DateTime.now().millisecondsSinceEpoch}.rfb');
    await file.writeAsBytes(compressed);
    
    return file;
  }
  
  /// Import from backup file
  Future<ImportResult> importBackup(File file) async {
    final compressed = await file.readAsBytes();
    final json = utf8.decode(gzip.decode(compressed));
    final data = jsonDecode(json);
    
    // Validate and import each section
    // ...
  }
}
```

## File Formats

### Routine Share (.rfr)
```json
{
  "format": "repforge-routine",
  "version": "1.0",
  "routine": {
    "name": "Push Day",
    "exercises": [...]
  }
}
```

### Full Backup (.rfb)
- Gzip compressed JSON
- Contains all user data
- Encrypted option for sensitive data

## Implementation Phases

### Phase 1: Core Sharing (3-4 days)
- [ ] Create `ShareableContent` model
- [ ] Implement `ShareService`
- [ ] QR code generation
- [ ] Copy link functionality

### Phase 2: Import Flow (3-4 days)
- [ ] QR code scanner integration
- [ ] Deep link handler
- [ ] Import preview screen
- [ ] Conflict resolution (duplicate names)

### Phase 3: Export/Backup (2-3 days)
- [ ] Full backup export
- [ ] Backup import
- [ ] File picker integration
- [ ] Progress indicators for large backups

### Phase 4: PR Sharing (2 days)
- [ ] PR share image generation
- [ ] Social media share integration
- [ ] Customizable share templates

### Phase 5: Polish (1-2 days)
- [ ] Error handling and user feedback
- [ ] Offline support
- [ ] Unit and integration tests

## Dependencies

```yaml
dependencies:
  qr_flutter: ^4.1.0          # QR code generation
  mobile_scanner: ^3.5.5       # QR code scanning
  share_plus: ^7.2.1          # System share sheet
  uni_links: ^0.5.1           # Deep linking
  file_picker: ^6.1.1         # File selection
  path_provider: ^2.1.1       # File storage
  archive: ^3.4.9             # Compression
```

## Security Considerations

1. **Data Validation** - Validate all imported data structure
2. **Version Checking** - Ensure compatibility before import
3. **Checksum Verification** - Detect corrupted data
4. **Size Limits** - Prevent oversized QR codes/links
5. **No Sensitive Data** - Don't include personal info in shares
6. **Sanitize Inputs** - Prevent injection attacks

## Edge Cases

1. **Large routines** - QR code has data limits (~4KB)
2. **Custom exercises** - Include in share if used
3. **Duplicate names** - Append "(imported)" suffix
4. **Offline import** - Cache and process later
5. **Version mismatch** - Graceful degradation or rejection
6. **Corrupted data** - Clear error messaging

## Future Enhancements

- **Community Library** - Browse and download popular routines
- **Routine Ratings** - Users can rate shared routines
- **Follow Creators** - Get notified of new routines
- **Sync Across Devices** - Cloud-based sync
- **Collaborative Routines** - Edit routines together
