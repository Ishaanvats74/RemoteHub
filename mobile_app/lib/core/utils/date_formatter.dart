class DateFormatter {
  static String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }
  }

  static String formatIsoRelative(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Never';
    try {
      final parsed = DateTime.parse(isoString);
      return formatRelativeTime(parsed.toLocal());
    } catch (_) {
      return isoString;
    }
  }

  static String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
