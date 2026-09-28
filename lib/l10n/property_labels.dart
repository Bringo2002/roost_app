import 'package:roost_app/l10n/generated/app_localizations.dart';
import 'package:roost_app/models/property.dart';

/// Localized, presentation-layer labels for a [Property].
///
/// These used to live on the model as `Property.bedroomDisplay`, which
/// baked English ("Studio", "Bedsitter", "bed"/"beds") into the data
/// layer. A model has no BuildContext and shouldn't know what language
/// the UI is in, so the formatting lives here instead, taking the
/// already-resolved [AppLocalizations].
extension PropertyLocalizedLabels on Property {
  /// "Studio" / "Bedsitter" for zero-bedroom listings (matching
  /// Zillow/Airbnb convention; unknown zero-bedroom types fall back to
  /// Studio), otherwise "1 bed" / "3 beds".
  String bedroomLabel(AppLocalizations l10n) {
    if (bedrooms <= 0) {
      return houseType.toUpperCase() == 'BEDSITTER'
          ? l10n.propertyTypeBedsitter
          : l10n.propertyTypeStudio;
    }
    return l10n.propertyBedroomCount(bedrooms);
  }
}
