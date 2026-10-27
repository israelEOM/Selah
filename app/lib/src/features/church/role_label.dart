import '../../../l10n/app_localizations.dart';
import '../../core/models.dart';

String roleLabel(AppLocalizations l, ChurchRole role) => switch (role) {
      ChurchRole.owner => l.roleOwner,
      ChurchRole.editor => l.roleEditor,
      ChurchRole.member => l.roleMember,
    };
