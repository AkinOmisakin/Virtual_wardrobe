import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';

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
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _watch() {
    // No channel filter: DELETE events only carry the PK in the old record,
    // so a user_id filter never matches. _fetch() already scopes by user_id.
    _channel = Supabase.instance.client
        .channel('clothing_items_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clothing_items',
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}
