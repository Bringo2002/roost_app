/// Whether a neighbourhood suggested from the phone's location may be written
/// into the listing's location field.
///
/// A suggestion fills a field that is empty, or one still holding the previous
/// suggestion (so a better fix can replace it). It never replaces something
/// the lister typed or edited.
bool shouldApplyAreaSuggestion({
  required String currentText,
  required String? previousSuggestion,
}) {
  final text = currentText.trim();
  if (text.isEmpty) return true;
  return previousSuggestion != null && text == previousSuggestion;
}
