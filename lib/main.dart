import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/supabase_config.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/location_bloc.dart';
import 'bloc/collaborative_session_bloc.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase 
  await SupabaseConfig.initialize();

  // Inicializar la instancia global del CollaborativeSessionBloc
  initializeGlobalCollaborativeSessionBloc();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()..add(AuthStarted())),
        BlocProvider(create: (context) => LocationBloc()),
        // Usar la instancia global
        BlocProvider<CollaborativeSessionBloc>.value(
          value: globalCollaborativeSessionBloc,
        ),
      ],
      child: MaterialApp(
        title: 'TopoTracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const HomeScreen();
            } else if (state is AuthLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}
