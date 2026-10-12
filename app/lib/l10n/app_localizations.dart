import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @tagline.
  ///
  /// In es, this message translates to:
  /// **'La Palabra que permanece'**
  String get tagline;

  /// No description provided for @heroEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Estudia más allá del domingo'**
  String get heroEyebrow;

  /// No description provided for @heroBody.
  ///
  /// In es, this message translates to:
  /// **'Continúa durante la semana lo que se predicó el domingo.'**
  String get heroBody;

  /// No description provided for @devotionalOfTheWeek.
  ///
  /// In es, this message translates to:
  /// **'Devocional de la semana'**
  String get devotionalOfTheWeek;

  /// No description provided for @recentStudies.
  ///
  /// In es, this message translates to:
  /// **'Estudios recientes'**
  String get recentStudies;

  /// No description provided for @noStudiesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay estudios publicados. Vuelve pronto.'**
  String get noStudiesYet;

  /// No description provided for @startDevotional.
  ///
  /// In es, this message translates to:
  /// **'Comenzar devocional'**
  String get startDevotional;

  /// No description provided for @daysCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Estudio de 1 día} other{Devocional de {count} días}}'**
  String daysCount(int count);

  /// No description provided for @loadError.
  ///
  /// In es, this message translates to:
  /// **'No fue posible cargar el contenido. Revisa tu conexión.'**
  String get loadError;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get passwordHint;

  /// No description provided for @haveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo una cuenta'**
  String get haveAccount;

  /// No description provided for @needAccount.
  ///
  /// In es, this message translates to:
  /// **'No tengo cuenta'**
  String get needAccount;

  /// No description provided for @confirmEmailSent.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un correo para confirmar tu cuenta. Ábrelo y vuelve a iniciar sesión.'**
  String get confirmEmailSent;

  /// No description provided for @invalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos.'**
  String get invalidCredentials;

  /// No description provided for @genericError.
  ///
  /// In es, this message translates to:
  /// **'No fue posible completar esta acción.'**
  String get genericError;

  /// No description provided for @admin.
  ///
  /// In es, this message translates to:
  /// **'Administrar'**
  String get admin;

  /// No description provided for @adminTitle.
  ///
  /// In es, this message translates to:
  /// **'Predicaciones'**
  String get adminTitle;

  /// No description provided for @adminOnly.
  ///
  /// In es, this message translates to:
  /// **'Esta sección es solo para administradores de la iglesia.'**
  String get adminOnly;

  /// No description provided for @adminEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se ha importado ninguna predicación.'**
  String get adminEmpty;

  /// No description provided for @importSermon.
  ///
  /// In es, this message translates to:
  /// **'Importar sermón'**
  String get importSermon;

  /// No description provided for @comingSoon.
  ///
  /// In es, this message translates to:
  /// **'Disponible en la siguiente fase.'**
  String get comingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
