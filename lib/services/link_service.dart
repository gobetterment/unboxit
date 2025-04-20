import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/link.dart';

class LinkService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Link>> getLinks() async {
    final response = await _supabase
        .from('links')
        .select()
        .order('created_at', ascending: false);

    return response.map((json) => Link.fromJson(json)).toList();
  }

  Future<void> saveLink(String title, String url, List<String> tags) async {
    await _supabase.from('links').insert({
      'title': title,
      'url': url,
      'tags': tags,
    });
  }

  Future<void> deleteLink(String id) async {
    await _supabase.from('links').delete().eq('id', id);
  }
}
