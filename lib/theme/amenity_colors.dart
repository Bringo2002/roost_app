import 'package:flutter/material.dart';

/// Icon colors for the amenity picker in the add-property flow, one per
/// amenity (named by the amenity key). Colors are decorative and per-item
/// by design, so they live here rather than in [AppColors]; values are
/// byte-identical to the literals they replaced.
class AmenityColors {
  AmenityColors._();

  static const Color water = Color(0xFF29B6F6);
  static const Color generator = Color(0xFFFFB74D);
  static const Color solar = Color(0xFFFFD54F);
  static const Color ac = Color(0xFF81D4FA);
  static const Color heating = Color(0xFFFF8A65);
  static const Color laundry = Color(0xFF90CAF9);
  static const Color dstv = Color(0xFFAB47BC);
  static const Color security = Color(0xFFFF9F43);
  static const Color fence = Color(0xFFFF7043);
  static const Color intercom = Color(0xFFBA68C8);
  static const Color elevator = Color(0xFF4DB6AC);
  static const Color parking = Color(0xFF4FC3F7);
  static const Color caretaker = Color(0xFFA1887F);
  static const Color balcony = Color(0xFFA5D6A7);
  static const Color rooftop = Color(0xFFB39DDB);
  static const Color garden = Color(0xFF81C784);
  static const Color storage = Color(0xFFDCE775);
  static const Color pool = Color(0xFF4DD0E1);
  static const Color gym = Color(0xFFFF8A65);
  static const Color playArea = Color(0xFFF48FB1);
  static const Color petFriendly = Color(0xFFEF9A9A);
  static const Color cleaning = Color(0xFF80CBC4);
  static const Color garbage = Color(0xFFB0BEC5);
  static const Color wheelchair = Color(0xFF9FA8DA);
}
