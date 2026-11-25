import 'package:flutter/material.dart';

import 'screens/job_board_screen.dart';
import 'services/api_service.dart';

/// Entry point dell'app: inizializza IP server + sessione salvata, poi avvia la UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();
  runApp(const JobSearchMvpApp());
}

/// Widget radice con tema Material 3 e schermata iniziale pubblica (Bacheca Lavoro).
class JobSearchMvpApp extends StatelessWidget {
  const JobSearchMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobSearch MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const JobBoardScreen(),
    );
  }
}
