import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:voxa/core/services/notification_service.dart';
import 'package:voxa/core/theme/app_theme.dart';
import 'package:voxa/core/theme/theme_controller.dart';
import 'package:voxa/screens/auth/phone_number_screen.dart';
import 'package:voxa/screens/home/home_screen.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  NotificationService.instance.setNavigatorKey(navigatorKey);
  await NotificationService.instance.init();

  final isSignedIn = FirebaseAuth.instance.currentUser != null;

  runApp(MyApp(isSignedIn: isSignedIn));
  
  // Remove splash screen after app is ready
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  final bool isSignedIn;

  const MyApp({super.key, required this.isSignedIn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Voxa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.themeMode,
          home: isSignedIn ? const HomeScreen() : const PhoneNumberScreen(),
        );
      },
    );
  }
}
