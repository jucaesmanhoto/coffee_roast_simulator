import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/screens.dart';

class CoffeeRoastApp extends StatelessWidget {
  const CoffeeRoastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffee Roast Simulator',
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const RoasterScreen(),
    );
  }
}
