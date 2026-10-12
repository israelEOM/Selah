// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tagline => 'La Palabra que permanece';

  @override
  String get heroEyebrow => 'Estudia más allá del domingo';

  @override
  String get heroBody =>
      'Continúa durante la semana lo que se predicó el domingo.';

  @override
  String get devotionalOfTheWeek => 'Devocional de la semana';

  @override
  String get recentStudies => 'Estudios recientes';

  @override
  String get noStudiesYet => 'Aún no hay estudios publicados. Vuelve pronto.';

  @override
  String get startDevotional => 'Comenzar devocional';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Devocional de $count días',
      one: 'Estudio de 1 día',
    );
    return '$_temp0';
  }

  @override
  String get loadError =>
      'No fue posible cargar el contenido. Revisa tu conexión.';

  @override
  String get retry => 'Reintentar';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get email => 'Correo';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordHint => 'Mínimo 8 caracteres';

  @override
  String get haveAccount => 'Ya tengo una cuenta';

  @override
  String get needAccount => 'No tengo cuenta';

  @override
  String get confirmEmailSent =>
      'Te enviamos un correo para confirmar tu cuenta. Ábrelo y vuelve a iniciar sesión.';

  @override
  String get invalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get genericError => 'No fue posible completar esta acción.';

  @override
  String get admin => 'Administrar';

  @override
  String get adminTitle => 'Predicaciones';

  @override
  String get adminOnly =>
      'Esta sección es solo para administradores de la iglesia.';

  @override
  String get adminEmpty => 'Todavía no se ha importado ninguna predicación.';

  @override
  String get importSermon => 'Importar sermón';

  @override
  String get comingSoon => 'Disponible en la siguiente fase.';
}
