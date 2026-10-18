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

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @newSermonTitle.
  ///
  /// In es, this message translates to:
  /// **'Comienza con el video'**
  String get newSermonTitle;

  /// No description provided for @youtubeUrl.
  ///
  /// In es, this message translates to:
  /// **'URL de YouTube'**
  String get youtubeUrl;

  /// No description provided for @findVideo.
  ///
  /// In es, this message translates to:
  /// **'Buscar video'**
  String get findVideo;

  /// No description provided for @searchingVideo.
  ///
  /// In es, this message translates to:
  /// **'Consultando YouTube…'**
  String get searchingVideo;

  /// No description provided for @workerHint.
  ///
  /// In es, this message translates to:
  /// **'El trabajo sigue en cola. Comprueba que el worker esté en marcha en tu Mac.'**
  String get workerHint;

  /// No description provided for @captionLanguage.
  ///
  /// In es, this message translates to:
  /// **'Subtítulos del sermón'**
  String get captionLanguage;

  /// No description provided for @autoGenerated.
  ///
  /// In es, this message translates to:
  /// **'automáticos'**
  String get autoGenerated;

  /// No description provided for @outputLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma del estudio'**
  String get outputLanguage;

  /// No description provided for @bibleVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión de la Biblia'**
  String get bibleVersion;

  /// No description provided for @sermonRange.
  ///
  /// In es, this message translates to:
  /// **'Parte del video'**
  String get sermonRange;

  /// No description provided for @fullVideo.
  ///
  /// In es, this message translates to:
  /// **'Video completo'**
  String get fullVideo;

  /// No description provided for @customRange.
  ///
  /// In es, this message translates to:
  /// **'Intervalo'**
  String get customRange;

  /// No description provided for @fullVideoHint.
  ///
  /// In es, this message translates to:
  /// **'Selah detecta dónde empieza y termina la predicación dentro del video.'**
  String get fullVideoHint;

  /// No description provided for @rangeStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio (HH:MM:SS)'**
  String get rangeStart;

  /// No description provided for @rangeEnd.
  ///
  /// In es, this message translates to:
  /// **'Fin (HH:MM:SS)'**
  String get rangeEnd;

  /// No description provided for @rangeInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa el intervalo: el fin debe ser posterior al inicio.'**
  String get rangeInvalid;

  /// No description provided for @devotionalLength.
  ///
  /// In es, this message translates to:
  /// **'Duración del devocional'**
  String get devotionalLength;

  /// No description provided for @daysShort.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String daysShort(int count);

  /// No description provided for @generateStudy.
  ///
  /// In es, this message translates to:
  /// **'Generar estudio'**
  String get generateStudy;

  /// No description provided for @progress.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get progress;

  /// No description provided for @stepTranscript.
  ///
  /// In es, this message translates to:
  /// **'Obtener subtítulos de YouTube'**
  String get stepTranscript;

  /// No description provided for @stepAnalysis.
  ///
  /// In es, this message translates to:
  /// **'Analizar el sermón e identificar referencias bíblicas'**
  String get stepAnalysis;

  /// No description provided for @stepSummary.
  ///
  /// In es, this message translates to:
  /// **'Redactar el resumen'**
  String get stepSummary;

  /// No description provided for @stepDevotional.
  ///
  /// In es, this message translates to:
  /// **'Generar el devocional'**
  String get stepDevotional;

  /// No description provided for @retryStep.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retryStep;

  /// No description provided for @jobAlreadyRunning.
  ///
  /// In es, this message translates to:
  /// **'Ya hay un trabajo en curso para este paso.'**
  String get jobAlreadyRunning;

  /// No description provided for @analysisSection.
  ///
  /// In es, this message translates to:
  /// **'Análisis del sermón'**
  String get analysisSection;

  /// No description provided for @mainPassage.
  ///
  /// In es, this message translates to:
  /// **'Pasaje principal'**
  String get mainPassage;

  /// No description provided for @centralTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema central'**
  String get centralTheme;

  /// No description provided for @sermonPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos del sermón'**
  String get sermonPoints;

  /// No description provided for @referencesSection.
  ///
  /// In es, this message translates to:
  /// **'Referencias bíblicas'**
  String get referencesSection;

  /// No description provided for @referencesHint.
  ///
  /// In es, this message translates to:
  /// **'Solo las referencias activadas se muestran a los miembros.'**
  String get referencesHint;

  /// No description provided for @refExplicit.
  ///
  /// In es, this message translates to:
  /// **'Citada'**
  String get refExplicit;

  /// No description provided for @refQuoted.
  ///
  /// In es, this message translates to:
  /// **'Texto citado'**
  String get refQuoted;

  /// No description provided for @refPossible.
  ///
  /// In es, this message translates to:
  /// **'Posible'**
  String get refPossible;

  /// No description provided for @studySection.
  ///
  /// In es, this message translates to:
  /// **'Estudio'**
  String get studySection;

  /// No description provided for @statusDraft.
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get statusDraft;

  /// No description provided for @statusGenerating.
  ///
  /// In es, this message translates to:
  /// **'Generando'**
  String get statusGenerating;

  /// No description provided for @statusReview.
  ///
  /// In es, this message translates to:
  /// **'En revisión'**
  String get statusReview;

  /// No description provided for @statusPublished.
  ///
  /// In es, this message translates to:
  /// **'Publicado'**
  String get statusPublished;

  /// No description provided for @publish.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get publish;

  /// No description provided for @unpublish.
  ///
  /// In es, this message translates to:
  /// **'Retirar publicación'**
  String get unpublish;

  /// No description provided for @published.
  ///
  /// In es, this message translates to:
  /// **'Estudio publicado. Ya está disponible para la iglesia.'**
  String get published;

  /// No description provided for @regenerateDevotional.
  ///
  /// In es, this message translates to:
  /// **'Regenerar devocional'**
  String get regenerateDevotional;

  /// No description provided for @regenerateAll.
  ///
  /// In es, this message translates to:
  /// **'Volver a analizar todo'**
  String get regenerateAll;

  /// No description provided for @watchMoment.
  ///
  /// In es, this message translates to:
  /// **'Ver este momento ({time})'**
  String watchMoment(String time);

  /// No description provided for @watchSermon.
  ///
  /// In es, this message translates to:
  /// **'Ver la predicación original'**
  String get watchSermon;

  /// No description provided for @dayLabel.
  ///
  /// In es, this message translates to:
  /// **'Día {number}'**
  String dayLabel(int number);

  /// No description provided for @reading.
  ///
  /// In es, this message translates to:
  /// **'Lectura'**
  String get reading;

  /// No description provided for @mainIdea.
  ///
  /// In es, this message translates to:
  /// **'Idea principal'**
  String get mainIdea;

  /// No description provided for @reflection.
  ///
  /// In es, this message translates to:
  /// **'Reflexión'**
  String get reflection;

  /// No description provided for @application.
  ///
  /// In es, this message translates to:
  /// **'Para practicar hoy'**
  String get application;

  /// No description provided for @questions.
  ///
  /// In es, this message translates to:
  /// **'Para reflexionar'**
  String get questions;

  /// No description provided for @prayer.
  ///
  /// In es, this message translates to:
  /// **'Oración'**
  String get prayer;

  /// No description provided for @keyTakeaways.
  ///
  /// In es, this message translates to:
  /// **'Para recordar'**
  String get keyTakeaways;

  /// No description provided for @notGeneratedYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se ha generado.'**
  String get notGeneratedYet;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @orWithEmail.
  ///
  /// In es, this message translates to:
  /// **'o con tu correo'**
  String get orWithEmail;

  /// No description provided for @oauthCancelled.
  ///
  /// In es, this message translates to:
  /// **'No se completó el inicio de sesión. Inténtalo de nuevo.'**
  String get oauthCancelled;

  /// No description provided for @oauthFailed.
  ///
  /// In es, this message translates to:
  /// **'No fue posible iniciar sesión con esa cuenta. Inténtalo de nuevo o usa tu correo.'**
  String get oauthFailed;

  /// No description provided for @embeddedBrowserHint.
  ///
  /// In es, this message translates to:
  /// **'Para entrar con Google, abre esta página en Safari o Chrome.'**
  String get embeddedBrowserHint;

  /// No description provided for @dayOfTotal.
  ///
  /// In es, this message translates to:
  /// **'Día {number} de {total}'**
  String dayOfTotal(int number, int total);

  /// No description provided for @previousDay.
  ///
  /// In es, this message translates to:
  /// **'Día anterior'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In es, this message translates to:
  /// **'Día siguiente'**
  String get nextDay;

  /// No description provided for @devotionalPath.
  ///
  /// In es, this message translates to:
  /// **'Camino devocional'**
  String get devotionalPath;

  /// No description provided for @sermonSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen de la predicación'**
  String get sermonSummary;

  /// No description provided for @readReference.
  ///
  /// In es, this message translates to:
  /// **'Leer {reference} ({version})'**
  String readReference(String reference, String version);

  /// No description provided for @externalReaderNote.
  ///
  /// In es, this message translates to:
  /// **'La lectura se abre en un lector externo; Selah no guarda el texto bíblico.'**
  String get externalReaderNote;

  /// No description provided for @prayerNote.
  ///
  /// In es, this message translates to:
  /// **'Oración sugerida a partir del estudio; no es una cita del predicador.'**
  String get prayerNote;

  /// No description provided for @markRead.
  ///
  /// In es, this message translates to:
  /// **'Marcar como leído'**
  String get markRead;

  /// No description provided for @markedRead.
  ///
  /// In es, this message translates to:
  /// **'Leído'**
  String get markedRead;

  /// No description provided for @studyNotFound.
  ///
  /// In es, this message translates to:
  /// **'Este estudio no está disponible.'**
  String get studyNotFound;

  /// No description provided for @backToStudy.
  ///
  /// In es, this message translates to:
  /// **'Volver al estudio'**
  String get backToStudy;

  /// No description provided for @watchThisPart.
  ///
  /// In es, this message translates to:
  /// **'Ver esta parte de la predicación'**
  String get watchThisPart;

  /// No description provided for @aiNotice.
  ///
  /// In es, this message translates to:
  /// **'Resumen y devocional preparados con ayuda de IA a partir de la predicación, y revisados por la iglesia. La predicación y la Escritura son la fuente.'**
  String get aiNotice;
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
