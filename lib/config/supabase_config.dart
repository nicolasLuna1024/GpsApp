import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = "https://jqoabinjonqgedgbrryi.supabase.co";
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impxb2FiaW5qb25xZ2VkZ2JycnlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg0NTkzNDAsImV4cCI6MjA2NDAzNTM0MH0.Ixtfn8U6F8gC-g5zS9w2V2tqvRZwrnojoJSLcG5P2LU';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Solo para desarrollo
    );
  }
}
