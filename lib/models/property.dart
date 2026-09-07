import 'dart:convert';

import 'package:roost_app/models/user.dart';

/// A nearby point of interest (closest mall, hospital, or major road),
/// computed once server-side when a listing's GPS location is verified.
/// Pure data -- category-to-icon mapping lives in the UI layer, not here.
class NearbyFacility {
  final String name;
  final String category; // 'mall' | 'hospital' | 'road'
  final double distanceMeters;

  const NearbyFacility({
    required this.name,
    required this.category,
    required this.distanceMeters,
  });

  factory NearbyFacility.fromJson(Map<String, dynamic> json) {
    return NearbyFacility(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// e.g. "600m from TRM Mall" or "1.2km from Thika Superhighway".
  String get label {
    final dist = distanceMeters < 1000
        ? '${distanceMeters.round()}m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    return '$dist from $name';
  }
}

class Property {
  final int? id;
  final String title;
  final String? buildingName;
  final String description;
  final String location;
  final double price;
  final int bedrooms;
  final String type;
  final String landlordPhone;
  final String? landlordName;
  final String? landlordId;
  final bool available;
  final String? imageUrl;
  final bool verified;
  final bool gpsVerified;
  final bool communityVerified;
  final String status;
  final double? latitude;
  final double? longitude;
  final User? owner;
  final List<String> imageUrls;
  final double averageRating;
  final int reviewCount;
  final int reportCount;
  final String? videoUrl;

  final String houseType;
  final int bathrooms;
  final bool furnished;
  final bool parking;
  final bool water;
  final bool wifi;
  final bool security;
  final bool petFriendly;
  final bool balcony;

  // Extended amenity fields
  final bool ac;
  final bool heating;
  final bool laundry;
  final bool dstv;
  final bool fence;
  final bool intercom;
  final bool elevator;
  final bool caretaker;
  final bool rooftop;
  final bool garden;
  final bool storage;
  final bool pool;
  final bool gym;
  final bool playArea;
  final bool cleaning;
  final bool garbage;
  final bool wheelchair;
  final bool solar;
  final bool generator;

  final String? deposit;
  final String? moveInDate;
  final int viewCount;
  final int saveCount;
  final String? listedAt;
  final String? lastConfirmedAt;
  final String country;
  final List<NearbyFacility> nearbyFacilities;
  final List<String> customAmenities;

  Property({
    this.id,
    required this.title,
    this.buildingName,
    required this.description,
    required this.location,
    required this.price,
    required this.bedrooms,
    required this.type,
    required this.landlordPhone,
    this.landlordName,
    this.landlordId,
    required this.available,
    this.imageUrl,
    this.verified = false,
    this.gpsVerified = false,
    this.communityVerified = false,
    this.status = 'PUBLISHED',
    this.latitude,
    this.longitude,
    this.owner,
    this.imageUrls = const [],
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.reportCount = 0,
    this.videoUrl,
    this.houseType = 'BEDSITTER',
    this.bathrooms = 1,
    this.furnished = false,
    this.parking = false,
    this.water = true,
    this.wifi = false,
    this.security = true,
    this.petFriendly = false,
    this.balcony = false,
    this.ac = false,
    this.heating = false,
    this.laundry = false,
    this.dstv = false,
    this.fence = false,
    this.intercom = false,
    this.elevator = false,
    this.caretaker = false,
    this.rooftop = false,
    this.garden = false,
    this.storage = false,
    this.pool = false,
    this.gym = false,
    this.playArea = false,
    this.cleaning = false,
    this.garbage = false,
    this.wheelchair = false,
    this.solar = false,
    this.generator = false,
    this.deposit,
    this.moveInDate,
    this.viewCount = 0,
    this.saveCount = 0,
    this.listedAt,
    this.lastConfirmedAt,
    this.country = 'KE',
    this.nearbyFacilities = const [],
    this.customAmenities = const [],
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] ?? '',
      buildingName: json['buildingName']?.toString(),
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 0,
      type: json['type'] ?? 'RENTAL',
      landlordPhone: json['landlordPhone'] ?? '',
      landlordName: json['landlordName']?.toString(),
      landlordId: json['landlordId']?.toString(),
      available: json['available'] ?? true,
      imageUrl: json['imageUrl']?.toString(),
      verified: json['verified'] ?? false,
      gpsVerified: json['gpsVerified'] ?? false,
      communityVerified: json['communityVerified'] ?? false,
      status: json['status'] ?? 'PUBLISHED',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      owner: json['owner'] is Map<String, dynamic> ? User.fromJson(json['owner']) : null,
      imageUrls: json['imageUrls'] is List ? (json['imageUrls'] as List).map((e) => e.toString()).toList() : [],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      videoUrl: json['videoUrl']?.toString(),
      houseType: json['houseType']?.toString() ?? 'BEDSITTER',
      bathrooms: (json['bathrooms'] as num?)?.toInt() ?? 1,
      furnished: json['furnished'] == true,
      parking: json['parking'] == true,
      water: json['water'] != false,
      wifi: json['wifi'] == true,
      security: json['security'] != false,
      petFriendly: json['petFriendly'] == true,
      balcony: json['balcony'] == true,
      ac: json['ac'] == true,
      heating: json['heating'] == true,
      laundry: json['laundry'] == true,
      dstv: json['dstv'] == true,
      fence: json['fence'] == true,
      intercom: json['intercom'] == true,
      elevator: json['elevator'] == true,
      caretaker: json['caretaker'] == true,
      rooftop: json['rooftop'] == true,
      garden: json['garden'] == true,
      storage: json['storage'] == true,
      pool: json['pool'] == true,
      gym: json['gym'] == true,
      playArea: json['playArea'] == true,
      cleaning: json['cleaning'] == true,
      garbage: json['garbage'] == true,
      wheelchair: json['wheelchair'] == true,
      solar: json['solar'] == true,
      generator: json['generator'] == true,
      deposit: json['deposit']?.toString(),
      moveInDate: json['moveInDate']?.toString(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      listedAt: json['listedAt']?.toString(),
      lastConfirmedAt: json['lastConfirmedAt']?.toString(),
      country: json['country']?.toString() ?? 'KE',
      nearbyFacilities: _parseNearbyFacilities(json['nearbyFacilities']),
      customAmenities: json['customAmenities'] is List
          ? (json['customAmenities'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }

  /// The backend stores/returns this as a raw JSON *string* (see
  /// Property.java's nearbyFacilities doc comment), not a nested array,
  /// so it needs an explicit decode here rather than a direct cast.
  /// Never throws -- malformed or missing data just means no facilities
  /// show, not a crash parsing the whole listing.
  static List<NearbyFacility> _parseNearbyFacilities(dynamic raw) {
    if (raw is! String || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NearbyFacility.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'buildingName': buildingName,
      'description': description,
      'location': location,
      'price': price,
      'bedrooms': bedrooms,
      'type': type,
      'landlordPhone': landlordPhone,
      if (landlordName != null) 'landlordName': landlordName,
      if (landlordId != null) 'landlordId': landlordId,
      'available': available,
      'imageUrl': imageUrl,
      'verified': verified,
      'gpsVerified': gpsVerified,
      'communityVerified': communityVerified,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'houseType': houseType,
      'bathrooms': bathrooms,
      'furnished': furnished,
      'parking': parking,
      'water': water,
      'wifi': wifi,
      'security': security,
      'petFriendly': petFriendly,
      'balcony': balcony,
      'ac': ac,
      'heating': heating,
      'laundry': laundry,
      'dstv': dstv,
      'fence': fence,
      'intercom': intercom,
      'elevator': elevator,
      'caretaker': caretaker,
      'rooftop': rooftop,
      'garden': garden,
      'storage': storage,
      'pool': pool,
      'gym': gym,
      'playArea': playArea,
      'cleaning': cleaning,
      'garbage': garbage,
      'wheelchair': wheelchair,
      'solar': solar,
      'generator': generator,
      if (deposit != null) 'deposit': deposit,
      'country': country,
      'customAmenities': customAmenities,
    };
  }

  /// Formatted bedroom display text.
  /// Converts 0 bedrooms to 'Studio' or 'Bedsitter' matching Zillow/Airbnb standard.
  String get bedroomDisplay {
    if (bedrooms <= 0) {
      final typeUpper = houseType.toUpperCase();
      if (typeUpper == 'STUDIO') return 'Studio';
      if (typeUpper == 'BEDSITTER') return 'Bedsitter';
      return 'Studio';
    }
    return '$bedrooms ${bedrooms == 1 ? 'bed' : 'beds'}';
  }
}
