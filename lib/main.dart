import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  // Use the correct path if .env is in lib/
  await dotenv.load(fileName: 'lib/.env');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp( // Removed Consumer here
        title: 'Chat Application',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        // Use AuthWrapper to handle initial routing based on auth state
        home: const AuthWrapper(),
      ),
    );
  }
}

// New stateful widget to handle initial auth loading and routing
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Call initAuth here in initState
    // Use Future.microtask to avoid calling notifyListeners during the very first build frame
    Future.microtask(() {
      Provider.of<AuthProvider>(context, listen: false).initAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider state changes
    final authProvider = Provider.of<AuthProvider>(context);

    // Show loading indicator while initializing
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Navigate based on authentication state
    return authProvider.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
  }
}
