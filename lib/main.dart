import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/login.dart';

void main() => runApp(const SkillArenaApp());

class SkillArenaApp extends StatelessWidget {
  const SkillArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillArena — Demo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LoginScreen(),
    );
  }
}
