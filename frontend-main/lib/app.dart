import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/home_screen.dart';

class BioTracerApp extends StatelessWidget {
  const BioTracerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioTracer · rastreabilidade de lotes',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
