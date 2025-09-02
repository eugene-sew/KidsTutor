import 'package:flutter/material.dart';
import 'modules_page.dart';
import 'settings_page.dart';
import 'ar_explore_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Start with Explore page (index 0)

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ARExplorePage(),
      const ModulesPage(),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: const Text('Explore and Learn'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black87,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Models',
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
