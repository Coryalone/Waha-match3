import 'package:flutter/material.dart';

void main() {
  runApp(const WahaMatch3App());
}

class WahaMatch3App extends StatelessWidget {
  const WahaMatch3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waha Match-3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFBFA76A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('Waha Match-3'),
          ),
        ),
      ),
    );
  }
}
