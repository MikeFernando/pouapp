import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

class PendingSync {
  const PendingSync({
    required this.id,
    required this.kind,
    required this.payload,
    required this.recordedAt,
  });

  final String id;
  final String kind;
  final String? payload;
  final String recordedAt;
}

/// Accepts one local operation. Returning false leaves it on the phone.
abstract class SyncTransport {
  Future<bool> deliver(PendingSync item);
}

/// There is no server yet. The queue stays on the phone.
class NoServerSyncTransport implements SyncTransport {
  const NoServerSyncTransport();

  @override
  Future<bool> deliver(PendingSync item) async => false;
}

/// Sends local operations when a connection exists. A missing server or a
/// dropped network leaves every row pending. The screen never waits for this.
class SyncWorker with WidgetsBindingObserver {
  SyncWorker({
    required this.openDatabase,
    required this.online,
    required this.transport,
  });

  final Future<Database> Function() openDatabase;
  final Future<bool> Function() online;
  final SyncTransport transport;
  var _busy = false;
  var _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(const Duration(seconds: 45), (_) => flush());
    flush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) flush();
  }

  Future<void> flush() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!await online()) return;
      final db = await openDatabase();
      final rows = await db.query(
        'pending_sync',
        where: 'status = ?',
        whereArgs: const ['local'],
        orderBy: 'recorded_at',
      );
      for (final row in rows) {
        final item = PendingSync(
          id: row['id']! as String,
          kind: row['kind']! as String,
          payload: row['payload'] as String?,
          recordedAt: row['recorded_at']! as String,
        );
        final accepted = await transport.deliver(item);
        if (!accepted) return;
        await db.update(
          'pending_sync',
          {'status': 'accepted'},
          where: 'id = ? AND status = ?',
          whereArgs: [item.id, 'local'],
        );
      }
    } catch (_) {
      // The next connection tries again. The local record stays.
    } finally {
      _busy = false;
    }
  }
}
