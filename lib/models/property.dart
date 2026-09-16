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
  final bool documentVerified;
  final bool communityVerified;
  final List<String> riskFlags;
  final String status;
  final double? latitude;
  final double? longitude;
  final User? owner;
  final List<String> imageUrls;
  final List<String> documentUrls;
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

  // Management Role & Caretaker fields
  final String managerRole; // 'LANDLORD' | 'CARETAKER' | 'AGENT'
  final String? caretakerName;
  final String? caretakerPhone;
  final bool caretakerLivesOnSite;
  final bool landlordEndorsed;
  final String? endorsementToken;
  final String? ownerVerifyName;
  final String? ownerVerifyPhone;

  // Utility & Move-in breakdown fields
  final int depositMonths;
  final double waterFee;
  final double garbageFee;
  final double serviceCharge;
  final String electricityType;

  double get totalInitialMoveInCost {
    final depositAmount = price * depositMonths;
    return price + depositAmount + waterFee + garbageFee + serviceCharge;
  }

  double get totalMonthlyUtilityCost {
    return price + waterFee + garbageFee + serviceCharge;
  }

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
    this.documentVerified = false,
    this.communityVerified = false,
    this.riskFlags = const [],
    this.status = 'PUBLISHED',
    this.latitude,
    this.longitude,
    this.owner,
    this.imageUrls = const [],
    this.documentUrls = const [],
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
    this.managerRole = 'LANDLORD',
    this.caretakerName,
    this.caretakerPhone,
    this.caretakerLivesOnSite = true,
    this.landlordEndorsed = false,
    this.endorsementToken,
    this.ownerVerifyName,
    this.ownerVerifyPhone,
    this.depositMonths = 1,
    this.waterFee = 1500.0,
    this.garbageFee = 500.0,
    this.serviceCharge = 2500.0,
    this.electricityType = 'tokens',
  });

  Property copyWith({
    int? id,
    String? title,
    String? buildingName,
    String? description,
    String? location,
    double? price,
    int? bedrooms,
    String? type,
    String? landlordPhone,
    String? landlordName,
    String? landlordId,
    bool? available,
    String? imageUrl,
    bool? verified,
    bool? gpsVerified,
    bool? documentVerified,
    bool? communityVerified,
    List<String>? riskFlags,
    String? status,
    double? latitude,
    double? longitude,
    User? owner,
    List<String>? imageUrls,
    List<String>? documentUrls,
    double? averageRating,
    int? reviewCount,
    int? reportCount,
    String? videoUrl,
    String? houseType,
    int? bathrooms,
    bool? furnished,
    bool? parking,
    bool? water,
    bool? wifi,
    bool? security,
    bool? petFriendly,
    bool? balcony,
    bool? ac,
    bool? heating,
    bool? laundry,
    bool? dstv,
    bool? fence,
    bool? intercom,
    bool? elevator,
    bool? caretaker,
    bool? rooftop,
    bool? garden,
    bool? storage,
    bool? pool,
    bool? gym,
    bool? playArea,
    bool? cleaning,
    bool? garbage,
    bool? wheelchair,
    bool? solar,
    bool? generator,
    String? deposit,
    String? moveInDate,
    int? viewCount,
    int? saveCount,
    String? listedAt,
    String? lastConfirmedAt,
    String? country,
    List<NearbyFacility>? nearbyFacilities,
    List<String>? customAmenities,
    String? managerRole,
    String? caretakerName,
    String? caretakerPhone,
    bool? caretakerLivesOnSite,
    bool? landlordEndorsed,
    String? endorsementToken,
    String? ownerVerifyName,
    String? ownerVerifyPhone,
  }) {
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      buildingName: buildingName ?? this.buildingName,
      description: description ?? this.description,
      location: location ?? this.location,
      price: price ?? this.price,
      bedrooms: bedrooms ?? this.bedrooms,
      type: type ?? this.type,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      landlordName: landlordName ?? this.landlordName,
      landlordId: landlordId ?? this.landlordId,
      available: available ?? this.available,
      imageUrl: imageUrl ?? this.imageUrl,
      verified: verified ?? this.verified,
      gpsVerified: gpsVerified ?? this.gpsVerified,
      documentVerified: documentVerified ?? this.documentVerified,
      communityVerified: communityVerified ?? this.communityVerified,
      riskFlags: riskFlags ?? this.riskFlags,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      owner: owner ?? this.owner,
      imageUrls: imageUrls ?? this.imageUrls,
      documentUrls: documentUrls ?? this.documentUrls,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      reportCount: reportCount ?? this.reportCount,
      videoUrl: videoUrl ?? this.videoUrl,
      houseType: houseType ?? this.houseType,
      bathrooms: bathrooms ?? this.bathrooms,
      furnished: furnished ?? this.furnished,
      parking: parking ?? this.parking,
      water: water ?? this.water,
      wifi: wifi ?? this.wifi,
      security: security ?? this.security,
      petFriendly: petFriendly ?? this.petFriendly,
      balcony: balcony ?? this.balcony,
      ac: ac ?? this.ac,
      heating: heating ?? this.heating,
      laundry: laundry ?? this.laundry,
      dstv: dstv ?? this.dstv,
      fence: fence ?? this.fence,
      intercom: intercom ?? this.intercom,
      elevator: elevator ?? this.elevator,
      caretaker: caretaker ?? this.caretaker,
      rooftop: rooftop ?? this.rooftop,
      garden: garden ?? this.garden,
      storage: storage ?? this.storage,
      pool: pool ?? this.pool,
      gym: gym ?? this.gym,
      playArea: playArea ?? this.playArea,
      cleaning: cleaning ?? this.cleaning,
      garbage: garbage ?? this.garbage,
      wheelchair: wheelchair ?? this.wheelchair,
      solar: solar ?? this.solar,
      generator: generator ?? this.generator,
      deposit: deposit ?? this.deposit,
      moveInDate: moveInDate ?? this.moveInDate,
      viewCount: viewCount ?? this.viewCount,
      saveCount: saveCount ?? this.saveCount,
      listedAt: listedAt ?? this.listedAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      country: country ?? this.country,
      nearbyFacilities: nearbyFacilities ?? this.nearbyFacilities,
      customAmenities: customAmenities ?? this.customAmenities,
      managerRole: managerRole ?? this.managerRole,
      caretakerName: caretakerName ?? this.caretakerName,
      caretakerPhone: caretakerPhone ?? this.caretakerPhone,
      caretakerLivesOnSite: caretakerLivesOnSite ?? this.caretakerLivesOnSite,
      landlordEndorsed: landlordEndorsed ?? this.landlordEndorsed,
      endorsementToken: endorsementToken ?? this.endorsementToken,
      ownerVerifyName: ownerVerifyName ?? this.ownerVerifyName,
      ownerVerifyPhone: ownerVerifyPhone ?? this.ownerVerifyPhone,
    );
  }

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
      documentVerified: json['documentVerified'] ?? false,
      communityVerified: json['communityVerified'] ?? false,
      status: json['status'] ?? 'PUBLISHED',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      owner: json['owner'] is Map<String, dynamic> ? User.fromJson(json['owner']) : null,
      imageUrls: json['imageUrls'] is List ? (json['imageUrls'] as List).map((e) => e.toString()).toList() : [],
      documentUrls: json['documentUrls'] is List ? (json['documentUrls'] as List).map((e) => e.toString()).toList() : [],
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
      riskFlags: json['riskFlags'] is List
          ? (json['riskFlags'] as List).map((e) => e.toString()).toList()
          : [],
      managerRole: json['managerRole']?.toString() ?? 'LANDLORD',
      caretakerName: json['caretakerName']?.toString(),
      caretakerPhone: json['caretakerPhone']?.toString(),
      caretakerLivesOnSite: json['caretakerLivesOnSite'] != false,
      landlordEndorsed: json['landlordEndorsed'] == true,
      endorsementToken: json['endorsementToken']?.toString(),
      ownerVerifyName: json['ownerVerifyName']?.toString(),
      ownerVerifyPhone: json['ownerVerifyPhone']?.toString(),
      depositMonths: (json['depositMonths'] as num?)?.toInt() ?? 1,
      waterFee: (json['waterFee'] as num?)?.toDouble() ?? 1500.0,
      garbageFee: (json['garbageFee'] as num?)?.toDouble() ?? 500.0,
      serviceCharge: (json['serviceCharge'] as num?)?.toDouble() ?? 2500.0,
      electricityType: json['electricityType']?.toString() ?? 'tokens',
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
      'documentVerified': documentVerified,
      'communityVerified': communityVerified,
      'riskFlags': riskFlags,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'documentUrls': documentUrls,
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
      'managerRole': managerRole,
      if (caretakerName != null) 'caretakerName': caretakerName,
      if (caretakerPhone != null) 'caretakerPhone': caretakerPhone,
      'caretakerLivesOnSite': caretakerLivesOnSite,
      'landlordEndorsed': landlordEndorsed,
      if (endorsementToken != null) 'endorsementToken': endorsementToken,
      if (ownerVerifyName != null) 'ownerVerifyName': ownerVerifyName,
      if (ownerVerifyPhone != null) 'ownerVerifyPhone': ownerVerifyPhone,
    };
  }

  // ─── Management Role Getters ───────────────────────────────────────────────

  bool get isDirectLandlord => managerRole == 'LANDLORD';
  bool get isCaretaker => managerRole == 'CARETAKER';
  bool get isAgent => managerRole == 'AGENT';

  /// Returns the display badge string shown on listing cards / detail pages.
  String get managementBadgeLabel {
    if (isDirectLandlord) return 'Direct Owner';
    if (isCaretaker) {
      return landlordEndorsed
          ? 'Landlord Endorsed Caretaker'
          : 'Caretaker Managed';
    }
    return landlordEndorsed ? 'Landlord Endorsed Agent' : 'Authorized Agent';
  }

  /// Name of the primary viewing contact (caretaker if present, else landlord).
  String get primaryViewingName =>
      (isCaretaker || isAgent) && (caretakerName?.isNotEmpty ?? false)
          ? caretakerName!
          : (landlordName ?? 'Landlord');

  /// Phone of the primary viewing contact.
  String get primaryViewingPhone =>
      (isCaretaker || isAgent) && (caretakerPhone?.isNotEmpty ?? false)
          ? caretakerPhone!
          : landlordPhone;

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
