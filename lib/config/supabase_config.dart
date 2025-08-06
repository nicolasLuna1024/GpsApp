import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = "https://rzksdeckvwjsglmikurl.supabase.co";
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ6a3NkZWNrdndqc2dsbWlrdXJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ0NDY4MTgsImV4cCI6MjA3MDAyMjgxOH0.cL5nvwBeAhZylOMJkzyAtGP2L8vGR-Ycu5xu89-RaQ8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Solo para desarrollo
    );
  }
}
