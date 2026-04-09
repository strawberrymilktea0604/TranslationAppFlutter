import 'package:flutter/material.dart';
import 'app_config.dart';

late AppConfig config;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName,
      home: Scaffold(
        body: Center(
          child: Text("API: ${config.apiUrl}"),
        ),
      ),
    );
  }
}