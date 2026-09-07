import 'package:flutter/material.dart';

import 'screens/search_screen.dart';

void main() {
  runApp(const GourmetSearchApp());
}

class GourmetSearchApp extends StatelessWidget {
  const GourmetSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gourmet Search',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const SearchScreen(),
    );
  }
}
