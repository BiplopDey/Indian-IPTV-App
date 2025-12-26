import 'package:flutter/material.dart';
import 'screens/home.dart';

void main() => runApp(const M3UPlayer());

class M3UPlayer extends StatefulWidget {
  const M3UPlayer({super.key});

  @override
  State<M3UPlayer> createState() => _M3UPlayerState();
}

class _M3UPlayerState extends State<M3UPlayer> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Tv',
      home: Home(),
    );
  }
}
