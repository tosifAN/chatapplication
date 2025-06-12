import 'package:chatapplication/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:chatapplication/main.dart';
import 'package:chatapplication/providers/auth_provider.dart';
import 'package:chatapplication/screens/home/home_screen.dart';
import 'package:chatapplication/screens/auth/login_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'main_test.mocks.dart';

@GenerateMocks([AuthProvider])
void main() {
  setUpAll(() async {
    // Initialize dotenv with empty or test values to prevent NotInitializedError
    dotenv.testLoad(fileInput: '');
    // Initialize Hive for tests without platform channels
    final testDir = Directory.current.path;
    Hive.init(path.join(testDir, 'test_hive'));
  });
  group('MyApp Widget Tests', () {
    testWidgets('MyApp renders AuthWrapper as home', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(mockAuthProvider.isLoading).thenReturn(false);
      when(mockAuthProvider.isAuthenticated).thenReturn(false);
      when(mockAuthProvider.currentUser).thenReturn(null);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ],
          child: const MaterialApp(home: AuthWrapper()),
        ),
      );
      expect(find.byType(AuthWrapper), findsOneWidget);
    });
  });

  group('AuthWrapper Widget Tests', () {
    testWidgets('Shows loading indicator when isLoading is true', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(mockAuthProvider.isLoading).thenReturn(true);
      when(mockAuthProvider.isAuthenticated).thenReturn(false);
      when(mockAuthProvider.currentUser).thenReturn(null);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuthProvider,
          child: const MaterialApp(home: AuthWrapper()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Shows HomeScreen when authenticated', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      final fakeUser = User.create(
        id: 'testid',
        username: 'testuser',
        email: 'test@example.com',
        lastSeen: DateTime.now(),
        isOnline: true,
      );
      when(mockAuthProvider.isLoading).thenReturn(false);
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      when(mockAuthProvider.currentUser).thenReturn(fakeUser);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuthProvider,
          child: const MaterialApp(home: AuthWrapper()),
        ),
      );
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Shows LoginScreen when not authenticated', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(mockAuthProvider.isLoading).thenReturn(false);
      when(mockAuthProvider.isAuthenticated).thenReturn(false);
      when(mockAuthProvider.currentUser).thenReturn(null);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuthProvider,
          child: const MaterialApp(home: AuthWrapper()),
        ),
      );
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
