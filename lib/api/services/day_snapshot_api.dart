import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../base/handler.dart';
import '../../models/auth_tokens.dart';
import '../../models/field_day.dart';
import 'my_day_service.dart';

/// Observes the existing day API. Home reloads still fetch; profile reuses data.
class DaySnapshotApi implements Handler<AuthTokens, String> {
  DaySnapshotApi(this.source);

  final Handler<AuthTokens, String> source;
  final snapshot = ValueNotifier<FieldDay?>(null);
  Future<String>? _pending;
  int _revision = 0;

  FieldDay? get current {
    final day = snapshot.value;
    final now = DateTime.now();
    return day != null &&
            day.date.year == now.year &&
            day.date.month == now.month &&
            day.date.day == now.day
        ? day
        : null;
  }

  @override
  Future<String> execute(AuthTokens input) {
    final pending = _pending;
    if (pending != null) return pending;
    final revision = _revision;
    late final Future<String> operation;
    operation = source
        .execute(input)
        .then((body) {
          final day = FieldDay.fromJson(
            jsonDecode(body) as Map<String, dynamic>,
          );
          if (revision == _revision) snapshot.value = day;
          return body;
        })
        .whenComplete(() {
          if (identical(_pending, operation)) _pending = null;
        });
    return _pending = operation;
  }

  Future<FieldDay> forProfile(MyDayService service) async =>
      current ?? await service.load();

  void clear() {
    _revision++;
    _pending = null;
    snapshot.value = null;
  }

  void dispose() {
    _revision++;
    snapshot.dispose();
  }
}
