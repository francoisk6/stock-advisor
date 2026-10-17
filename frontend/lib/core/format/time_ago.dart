import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// "5 minutes ago", "3 hours ago", "yesterday", then a date for anything older than a week.
String timeAgo(AppLocalizations l10n, DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 60) {
    return l10n.timeMinutesAgo(diff.inMinutes.clamp(1, 59));
  }
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  return DateFormat.yMMMd().format(when.toLocal());
}
