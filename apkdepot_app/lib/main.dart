import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api_service.dart';
import 'screens/beranda_screen.dart';
import 'screens/login_screen.dart';
import 'services/profile_image_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProfileImageService.instance.init();
  runApp(const SimodApp());
}

class SimodApp extends StatelessWidget {
  const SimodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIMOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: WarnaMod.biru,
        scaffoldBackgroundColor: WarnaMod.latar,
      ),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<bool>(
        future: ApiService.pulihkanSesi(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          if (snapshot.data == true && ApiService.sudahLogin) {
            return const BerandaScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaMod.latar,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: WarnaMod.header,
              ),
              child: const Icon(
                Icons.water_drop_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: WarnaMod.biru),
            const SizedBox(height: 12),
            const Text(
              'Memuat sesi...',
              style: TextStyle(color: WarnaMod.teksRedup),
            ),
          ],
        ),
      ),
    );
  }
}
