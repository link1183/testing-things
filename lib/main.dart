import 'package:flutter/material.dart';
import 'package:media_viewer/services/navigation_service.dart';
import 'package:media_viewer/services/service_locator.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/media_service.dart';
import 'services/storage_service.dart';
import 'services/preferences_service.dart';
import 'screens/home_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    size: Size(1280, 720),
    center: true,
    title: 'Media Viewer',
    minimumSize: Size(800, 600),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await setupServiceLocator();

  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<PreferencesService>()),
        ChangeNotifierProvider.value(value: getIt<StorageService>()),
        ChangeNotifierProvider.value(value: getIt<MediaService>()),
      ],
      child: AppContent(),
    );
  }
}

class AppContent extends StatelessWidget {
  const AppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferencesService>(
      builder: (context, preferences, _) {
        return MaterialApp(
          title: 'Media Viewer',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness:
                preferences.isDarkMode ? Brightness.dark : Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            useMaterial3: true,
          ),
          themeMode: preferences.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainScreen(),
          navigatorKey: NavigationService.navigatorKey,
        );
      },
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
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRandomMedia();
    });
  }

  void _loadRandomMedia() async {
    final mediaService = Provider.of<MediaService>(context, listen: false);
    await mediaService.loadRandomMediaOnStartup();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 1200,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: MediaQuery.of(context).size.width > 1200
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.photo_library),
                label: Text('Gallery'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text('Calendar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.collections),
                label: Text('Collections'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                HomeScreen(),
                GalleryScreen(),
                CalendarScreen(),
                CollectionsScreen(),
                SettingsScreen(),
              ],
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
