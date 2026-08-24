import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Shorthand for generated localizations: `context.l10n.someKey`.
extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
