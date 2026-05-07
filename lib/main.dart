
// lib/main.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/login_screen.dart'; // ADDED
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_edit_item_screen.dart';
import 'services/database_helper.dart';
import 'services/auth_service.dart'; // ADDED

void main() async {
  // Initialize FFI for desktop BEFORE runApp
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Test database connection
  try {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.database; // This will initialize the database
    print('🎉 Database ready!');
  } catch (e) {
    print('⚠️ Database initialization warning: $e');
    // Continue anyway - the app will handle errors gracefully
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockSync Inventory',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          centerTitle: true,
        ),
      ),
      // CHANGED: Use FutureBuilder to check login status
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          // Show loading while checking login status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If logged in, go to MainScreen, otherwise go to LoginScreen
          if (snapshot.data == true) {
            return const MainScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isDatabaseInitialized = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const InventoryScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      // Initialize database by accessing it once
      await DatabaseHelper.instance.database;
      print('✅ Database initialized successfully');
      setState(() {
        _isDatabaseInitialized = true;
      });
    } catch (e) {
      print('❌ Database initialization failed: $e');
      // Even if it fails, we'll still show the app with fallback data
      setState(() {
        _isDatabaseInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDatabaseInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing database...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
