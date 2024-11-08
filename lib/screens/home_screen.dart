import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'expense_list_screen.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of screens for each tab
  final List<Widget> _screens = [
    HomeScreenContent(), // Replace with actual screen widgets
    ExpenseListScreen(),
    DashboardScreen(),
    HistoryScreenContent(),
    ProfileScreenContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF1C1C1E), // Dark background color for bar
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 150, height: 150,), // Replace with your app logo
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class RecordScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Record Screen Content'));
  }
}

class AnalyticsScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Analytics Screen Content'));
  }
}

class HistoryScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('History feature currently under development'));
  }
}

class ProfileScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Profile feature currently under development'));
  }
}
