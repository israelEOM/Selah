import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/models.dart';

/// When the next event is, said the way a member would: Hoy, Mañana, Este sábado, or the date further out.
String heroDayLabel(DateTime localStart, DateTime today, AppLocalizations l) {
  final day = DateTime(localStart.year, localStart.month, localStart.day);
  final days = day.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (days <= 0) return l.eventsToday;
  if (days == 1) return l.eventsTomorrow;
  if (days <= 6) {
    final label = l.eventsThisWeekday(DateFormat.EEEE(l.localeName).format(day));
    return label[0].toUpperCase() + label.substring(1);
  }
  return shortDate(localStart, l);
}

/// `sáb 21 nov`.
String shortDate(DateTime date, AppLocalizations l) =>
    '${DateFormat.E(l.localeName).format(date)} ${date.day} ${DateFormat.MMM(l.localeName).format(date)}'
        .replaceAll('.', '');

/// `17:30 – 19:30`, or Todo el día.
String eventTimes(ChurchEvent event, AppLocalizations l) {
  if (event.allDay) return l.eventsAllDay;
  final time = DateFormat.Hm(l.localeName);
  return '${time.format(event.localStart)} – ${time.format(event.localEnd)}';
}
