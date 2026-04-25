import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/theme.dart';
import 'config/firebase_options.dart';
import 'models/driver.dart';
import 'models/tenant.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/tenant_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation early
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge dark system chrome
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Init local storage and PRELOAD persisted state synchronously so the
  // splash screen can route deterministically (no flicker, no race).
  await storageService.init();

  final savedTenant = storageService.getTenant();
  final savedDriver = storageService.getDriver();
  final savedToken = storageService.getAuthToken();

  if (savedTenant?.baseUrl != null) {
    apiService.setTenant(savedTenant!.baseUrl!);
  }
  if (savedToken != null) {
    apiService.setAuthToken(savedToken);
  }

  runApp(CliotelDriverApp(
    initialTenant: savedTenant,
    initialDriver: savedDriver,
    initialToken: savedToken,
  ));
}

class CliotelDriverApp extends StatelessWidget {
  final Tenant? initialTenant;
  final Driver? initialDriver;
  final String? initialToken;

  const CliotelDriverApp({
    super.key,
    this.initialTenant,
    this.initialDriver,
    this.initialToken,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TenantProvider(initialTenant: initialTenant),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            initialDriver: initialDriver,
            initialToken: initialToken,
          ),
        ),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Cliotel Driver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
