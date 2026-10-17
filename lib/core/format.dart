/// Human-readable byte size: 512 B, 12.4 KB, 3.1 MB, ...
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final rounded = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}
