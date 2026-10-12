import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';

/// All data access goes through here. Row-level security decides what each caller may see.
class SelahRepository {
  SelahRepository(this._client);

  final SupabaseClient _client;

  Future<List<StudyCard>> publishedStudies() async {
    final rows = await _client
        .from('studies')
        .select('id, slug, title, number_of_days, central_message, published_at, '
            'sermons(thumbnail_url, preacher, channel, sermon_date)')
        .eq('status', 'published')
        .order('published_at', ascending: false);
    return rows.map(StudyCard.fromJson).toList();
  }

  Future<bool> isAdmin(String userId) async {
    final row = await _client.from('profiles').select('role').eq('id', userId).maybeSingle();
    return row?['role'] == 'admin';
  }

  Future<List<SermonRow>> sermons() async {
    final rows = await _client
        .from('sermons')
        .select('id, title, youtube_url, thumbnail_url, studies(status)')
        .order('created_at', ascending: false);
    return rows.map(SermonRow.fromJson).toList();
  }

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Returns true when the account still needs email confirmation.
  Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return response.session == null;
  }

  Future<void> signOut() => _client.auth.signOut();
}
