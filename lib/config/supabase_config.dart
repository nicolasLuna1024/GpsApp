import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = "https://gwnktpeqpkroaudsxfpm.supabase.co";
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3bmt0cGVxcGtyb2F1ZHN4ZnBtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyMTEyMDgsImV4cCI6MjA2ODc4NzIwOH0.SdTPtAo04M9-osu6daSCC8pIqx58kOpdDhC3B0gUEq8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Solo para desarrollo
    );
  }
}
