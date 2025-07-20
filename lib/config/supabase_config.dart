import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = "https://joonxgidmxqqgtusssfo.supabase.co";
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impvb254Z2lkbXhxcWd0dXNzc2ZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4NTYwNTEsImV4cCI6MjA2ODQzMjA1MX0.BL9FwjuipBJDH0F_lbbEgzLkDVeGv7ObwrmfNT5q3A8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Solo para desarrollo
    );
  }
}
