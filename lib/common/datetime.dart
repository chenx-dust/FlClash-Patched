import 'package:flutter/widgets.dart';

import 'context.dart';

extension DateTimeExtension on DateTime {
  bool get isBeforeNow {
    return isBefore(DateTime.now());
  }

  bool isBeforeSecure(DateTime? dateTime) {
    if (dateTime == null) {
      return false;
    }
    return true;
  }

  String getLastUpdateTimeDesc(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    if (year <= 1970) {
      return appLocalizations.unknown;
    }
    final currentDateTime = DateTime.now();
    final difference = currentDateTime.difference(this);
    final days = difference.inDays;
    if (days >= 365) {
      final years = (days / 365).floor();
      return appLocalizations.yearsAgo(years);
    }
    if (days >= 30) {
      final months = (days / 30).floor();
      return appLocalizations.monthsAgo(months);
    }
    if (days >= 1) {
      return appLocalizations.daysAgo(days);
    }
    final hours = difference.inHours;
    if (hours >= 1) {
      return appLocalizations.hoursAgo(hours);
    }
    final minutes = difference.inMinutes;
    if (minutes >= 1) {
      return appLocalizations.minutesAgo(minutes);
    }
    return appLocalizations.justNow;
  }

  String get show {
    return toString().substring(0, 10);
  }

  String get showFull {
    return toString().substring(0, 19);
  }

  String get showTime {
    return toString().substring(10, 19);
  }
}

String getDateStringLast2(int value) {
  final valueRaw = '0$value';
  return valueRaw.substring(valueRaw.length - 2);
}

String getTimeText(int? timeStamp) {
  if (timeStamp == null) {
    return '00:00:00';
  }
  final totalSeconds = (timeStamp / 1000).floor();
  final inHours = (totalSeconds / Duration.secondsPerHour).floor();
  final inMinutes = (totalSeconds / Duration.secondsPerMinute).floor() % 60;
  final inSeconds = totalSeconds % 60;
  if (inHours >= Duration.hoursPerDay) {
    final inDays = (inHours / Duration.hoursPerDay).floor();
    final remainingHours = inHours % Duration.hoursPerDay;
    return '${inDays}d ${getDateStringLast2(remainingHours)}:${getDateStringLast2(inMinutes)}:${getDateStringLast2(inSeconds)}';
  }
  return '${getDateStringLast2(inHours)}:${getDateStringLast2(inMinutes)}:${getDateStringLast2(inSeconds)}';
}
