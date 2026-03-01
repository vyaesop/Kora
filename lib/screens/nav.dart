import 'package:flutter/material.dart';
import 'package:Kora/screens/home.dart';

class LogisticsMainPage extends StatefulWidget {
  const LogisticsMainPage({Key? key}) : super(key: key);

  @override
  State<LogisticsMainPage> createState() => _LogisticsMainPageState();
}

class _LogisticsMainPageState extends State<LogisticsMainPage> {
  @override
  Widget build(BuildContext context) {
    return const Home();
  }
}