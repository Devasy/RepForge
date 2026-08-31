import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('No coverage/lcov.info found.');
    return;
  }

  final lines = file.readAsLinesSync();
  int totalLines = 0;
  int hitLines = 0;
  
  Map<String, List<int>> fileCoverage = {};
  String currentFile = '';

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      final normalized = currentFile.replaceAll('\\', '/');
      if (normalized.contains('lib/services/ai/')) {
        fileCoverage[currentFile] = [0, 0]; // hits, total
      }
    } else if (line.startsWith('DA:')) {
      final normalized = currentFile.replaceAll('\\', '/');
      if (normalized.contains('lib/services/ai/')) {
        final parts = line.substring(3).split(',');
        if (parts.length == 2) {
          totalLines++;
          fileCoverage[currentFile]![1]++;
          final hits = int.tryParse(parts[1]) ?? 0;
          if (hits > 0) {
            hitLines++;
            fileCoverage[currentFile]![0]++;
          }
        }
      }
    }
  }

  if (totalLines == 0) {
    print('No executable lines found.');
  } else {
    final coverage = (hitLines / totalLines) * 100;
    print('Total AI Coverage: ${coverage.toStringAsFixed(2)}% ($hitLines/$totalLines lines)');
    
    // Sort files by missed lines (descending)
    var entries = fileCoverage.entries.toList()
      ..sort((a, b) {
        var missedA = a.value[1] - a.value[0];
        var missedB = b.value[1] - b.value[0];
        return missedB.compareTo(missedA);
      });
      
    print('\nBiggest files and their coverage:');
    for (var i = 0; i < 30 && i < entries.length; i++) {
      var entry = entries[i];
      var hits = entry.value[0];
      var total = entry.value[1];
      var pct = total > 0 ? (hits / total) * 100 : 0;
      var missed = total - hits;
      print('${entry.key}: ${pct.toStringAsFixed(1)}% ($hits/$total) - Missed: $missed lines');
    }
  }
}
