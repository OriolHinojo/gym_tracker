import 'package:flutter/material.dart';

/// Shared formatting helpers to keep date/time rendering consistent.

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formats a [DateTime] (already in local time) as `YYYY-MM-DD`.
String formatDateYmd(DateTime date) =>
    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

/// Formats a [DateTime] (already in local time) as `HH:MM`.
String formatTimeHm(DateTime date) =>
    '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

/// Formats a [DateTime] (already in local time) as `YYYY-MM-DD at HH:MM`.
String formatDateTimeYmdHm(DateTime date, {String separator = ' at '}) =>
    '${formatDateYmd(date)}$separator${formatTimeHm(date)}';

/// Formats a nullable [DateTime]; returns [fallback] when null.
String formatMaybeDateTime(DateTime? date,
        {String fallback = 'Unknown date', String separator = ' at '}) =>
    date == null ? fallback : formatDateTimeYmdHm(date, separator: separator);

/// Parses an ISO 8601 timestamp and formats it in local time.
String formatIso8601ToLocal(String? iso,
        {String fallback = 'Unknown date', String separator = ' at '}) =>
    formatMaybeDateTime(
      iso == null ? null : DateTime.tryParse(iso)?.toLocal(),
      fallback: fallback,
      separator: separator,
    );

/// Formats a duration as `MM:SS` regardless of hours elapsed.
String formatDurationMmSs(Duration duration) =>
    '${_twoDigits(duration.inMinutes % 60)}:${_twoDigits(duration.inSeconds % 60)}';

/// Formats a duration as `HH:MM:SS` when an hour has elapsed, otherwise `MM:SS`.
String formatDurationClock(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds ~/ 60) % 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }
  return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

/// Formats a [TimeOfDay] using `HH:MM`.
String formatTimeOfDay(TimeOfDay time) =>
    '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
