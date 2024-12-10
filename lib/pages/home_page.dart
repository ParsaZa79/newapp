import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_connect_page.dart';
import 'map_page.dart';
import 'playlist_page.dart';
import 'settings_page.dart';
import 'themeData.dart';
import 'package:lottie/lottie.dart'; // For dynamic animation

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    MyThemeColors currentColors = Provider.of<MyThemes>(context).currentColors;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: Lottie.asset(
              'lib/assets/animations/purple3.json', // Add your Lottie file here
              fit: BoxFit.cover,
              repeat: true,
              animate: true,
            ),
          ),
          Column(
            children: [
              // Custom Header
              Stack(
                children: [
                  // Header Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                            'lib/pages/pics/header.png'), // Your image path
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Fade Effect at the Bottom
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withOpacity(1.0), // Full opacity background
                            const Color.fromARGB(
                                0, 0, 0, 0), // Transparent top for fade
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      'Welcome, Rider!',
                      style: TextStyle(
                        color: currentColors.bodyText1,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // Buttons
              SizedBox(height: 40,),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildMenuButton(
                      context,
                      'Bluetooth',
                      Icons.bluetooth,
                      currentColors,
                      BluetoothDevicesPage(),
                    ),
                    _buildMenuButton(
                      context,
                      'Navigation',
                      Icons.map,
                      currentColors,
                      MapPage(),
                    ),
                    _buildMenuButton(
                      context,
                      'Playlist',
                      Icons.music_note,
                      currentColors,
                      PlaylistPage(),
                    ),
                    _buildMenuButton(
                      context,
                      'Settings',
                      Icons.settings,
                      currentColors,
                      SettingsPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon,
      MyThemeColors themeColors, Widget page) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(16),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: themeColors.iconColor),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: themeColors.bodyText1,
            ),
          ),
        ],
      ),
    );
  }
}
