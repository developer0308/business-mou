import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mou_business_app/core/models/country_phone_code.dart';
import 'package:mou_business_app/core/responses/register_response.dart';
import 'package:mou_business_app/helpers/provider_setup.dart';
import 'package:mou_business_app/helpers/push_notification_helper.dart';
import 'package:mou_business_app/managers/payments_manager.dart';
import 'package:mou_business_app/splash_screen.dart';
import 'package:mou_business_app/utils/app_colors.dart';
import 'package:mou_business_app/utils/app_constants.dart';
import 'package:mou_business_app/utils/app_globals.dart';
import 'package:mou_business_app/utils/app_languages.dart';
import 'package:mou_business_app/utils/app_shared.dart';
import 'package:mou_business_app/utils/app_theme.dart';
import 'package:mou_business_app/utils/app_utils.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'helpers/routers.dart';
import 'helpers/translations.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Purchases
  await PaymentsManager.initialize();

  // Initialized for Downloads
  await FlutterDownloader.initialize();

  // Initialize TimeZones/Language
  tz.initializeTimeZones();
  final RegisterResponse user = await AppShared.getUser();
  final String languageCode = user.settings?.languageCode ?? '';
  await allTranslations.init(languageCode);

  // Initialize Firebase
  // final firebaseConfig = FirebaseOptions(
  //     apiKey: "AIzaSyBM7djkev86Bkf0uDcqmaP7NQQ4u18Bta0",
  //     authDomain: "mou-business-f3417.firebaseapp.com",
  //     projectId: "mou-business-f3417",
  //     storageBucket: "mou-business-f3417.appspot.com",
  //     messagingSenderId: "837903231618",
  //     appId: "1:837903231618:web:a0807ebe414a3e5d0c229b",
  //     measurementId: "G-SVS2NVM3YP");
      
  await Firebase.initializeApp();

  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  // Initialized for Firebase Cloud Messaging
  await PushNotificationHelper.setupFirebaseFCM();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bgColor2,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(MultiProvider(providers: providers, child: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<bool>? _sessionExpiredSubs;

  @override
  void initState() {
    super.initState();
    _loadCountryCodes();
    _sessionExpiredSubs = AppGlobals.sessionExpiredSubject.listen((isExpired) {
      if (isExpired) {
        _showSessionExpiredDialog();
      }
    });
    allTranslations.onLocaleChangedCallback = _onLocaleChanged;
  }

  _loadCountryCodes() async {
    String jsonString =
        await rootBundle.loadString(AppConstants.countryCodesPath);
    List<Map<String, dynamic>> jsonData =
        json.decode(jsonString).cast<Map<String, dynamic>>();
    AppUtils.appCountryCodes =
        jsonData.map((e) => CountryPhoneCode.fromJson(e)).toList();
  }

  _onLocaleChanged() async {
    print('Language has been changed to: ${allTranslations.currentLanguage}');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mou Management App',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      localizationsDelegates: [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      locale: allTranslations.locale,
      supportedLocales: allTranslations.supportedLocales(),
      home: const SplashScreen(),
      onGenerateRoute: Routers.generateRoute,
    );
  }

  @override
  void dispose() {
    _sessionExpiredSubs?.cancel();
    super.dispose();
  }

  void _showSessionExpiredDialog() {
    final BuildContext? context = _navigatorKey.currentState?.context;
    if (context == null) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
              allTranslations.text(AppLanguages.sessionExpired).toUpperCase()),
          content: Text(
              allTranslations.text(AppLanguages.sessionExpiredDescriptions)),
          actions: <Widget>[
            CupertinoDialogAction(
              child:
                  Text(allTranslations.text(AppLanguages.login).toUpperCase()),
              onPressed: () => AppGlobals.logout(context),
            ),
          ],
        );
      },
    );
  }
}
