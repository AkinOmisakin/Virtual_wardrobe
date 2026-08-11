import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

class ItemProvider extends ChangeNotifier {
  final String? userId = Supabase.instance.client.auth.currentUser?.id;

  ItemProvider() {
    _init();
  }

  List<ClothingItem> _items = [];
  RealtimeChannel? _channel;
  bool _isLoading = true;
  String? _error;

  List<ClothingItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _init() async {
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    await _fetch();
    _watch();
  }

  Future<void> _fetch() async {
    try {
      final data = await Supabase.instance.client
          .from('clothing_items')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      _items = (data as List)
          .map((e) => ClothingItem.fromMap(e as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e, st) {
      _error = friendlyError(e,
          fallback: "Couldn't load your wardrobe. Please try again.",
          stackTrace: st);
      _isLoading = false;
      notifyListeners();
    }
  }

  void _watch() {
    // No channel filter: DELETE events only carry the PK in the old record,
    // so a user_id filter never matches. Instead of refetching the whole table
    // on every change, we apply each change to the in-memory list — and scope
    // to this user in the callback (INSERT/UPDATE carry the full row).
    _channel = Supabase.instance.client
        .channel('clothing_items_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clothing_items',
          callback: _onRealtimeChange,
        )
        .subscribe();
  }

  void _onRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _applyUpsert(payload.newRecord, insertAtFront: true);
        break;
      case PostgresChangeEvent.update:
        _applyUpsert(payload.newRecord, insertAtFront: false);
        break;
      case PostgresChangeEvent.delete:
        // DELETE payloads carry only the primary key in the old record.
        final id = payload.oldRecord['id'];
        if (id != null) _removeById(id.toString());
        break;
      case PostgresChangeEvent.all:
        break; // never delivered as a concrete event type
    }
  }

  /// Inserts or replaces an item from an INSERT/UPDATE payload, ignoring rows
  /// that belong to other users.
  void _applyUpsert(Map<String, dynamic> record, {required bool insertAtFront}) {
    if (record['user_id'] != userId) return;

    final item = ClothingItem.fromMap(record);
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      _items[idx] = item; // replace in place, preserving order
    } else {
      // New row (or an update for one we hadn't loaded): newest sorts first.
      _items.insert(0, item);
    }
    notifyListeners();
  }

  void _removeById(String id) {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    if (_items.length != before) notifyListeners();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}
