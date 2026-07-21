import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/maps_config.dart';
import 'maps_script_loader.dart';
import 'screens/login_screen.dart';
import 'screens/home/home_shell_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'services/profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Awaited (not fire-and-forget) so no screen can render a GoogleMap
  // before window.google.maps actually exists on web. Resolves
  // instantly on Android/iOS — see maps_script_loader_stub.dart.
  await injectGoogleMapsScript(MapsConfig.apiKey);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FMCG Sales App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Listens to Supabase auth state. Once logged in, checks the user's role
/// in `profiles` and routes to the Salesperson dashboard or Admin dashboard.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _profileService = ProfileService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return FutureBuilder(
          future: _profileService.getMyProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.hasError || !profileSnapshot.hasData) {
              // Profile row missing or failed to load — safest fallback is login.
              return const LoginScreen();
            }
            final profile = profileSnapshot.data!;
            if (profile.role == 'admin') {
              return const AdminHomeScreen();
            }
            if (!profile.isActive) {
              return const _AccountDeactivatedScreen();
            }
            return const HomeShellScreen();
          },
        );
      },
    );
  }
}

/// Shown when a salesperson's profile has been flagged 'inactive' by an
/// Admin (see AdminUserService.setSalesmanStatus). Signs them out
/// immediately — AuthGate's StreamBuilder then rebuilds to LoginScreen on
/// its own once the auth state change fires.
class _AccountDeactivatedScreen extends StatefulWidget {
  const _AccountDeactivatedScreen();

  @override
  State<_AccountDeactivatedScreen> createState() => _AccountDeactivatedScreenState();
}

class _AccountDeactivatedScreenState extends State<_AccountDeactivatedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => supabase.auth.signOut());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 56, color: Colors.red.shade400),
              const SizedBox(height: 16),
              const Text(
                'Account Deactivated',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account has been deactivated by an admin. Please contact your manager.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
