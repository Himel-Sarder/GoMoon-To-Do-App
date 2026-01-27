import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import './pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('tasksBox');

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoMoon',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(31, 31, 31, 1.0),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
