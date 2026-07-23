import 'package:roost_app/models/user.dart';

class Property {
  final int? id;
  final String title;
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
  final bool holdingFeePaid;
  final double? latitude;
  final double? longitude;
  final User? owner;
  final List<String> imageUrls;
  final double averageRating;
  final int reviewCount;
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
  final String? deposit;
  final String? moveInDate;
  final int viewCount;
  final int saveCount;
  final String? listedAt;
  final String? lastConfirmedAt;
  final String country;

  Property({
    this.id,
    required this.title,
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
    this.holdingFeePaid = false,
    this.latitude,
    this.longitude,
    this.owner,
    this.imageUrls = const [],
    this.averageRating = 0.0,
    this.reviewCount = 0,
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
    this.deposit,
    this.moveInDate,
    this.viewCount = 0,
    this.saveCount = 0,
    this.listedAt,
    this.lastConfirmedAt,
    this.country = 'KE',
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] ?? '',
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
      holdingFeePaid: json['holdingFeePaid'] ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      owner: json['owner'] is Map<String, dynamic> ? User.fromJson(json['owner']) : null,
      imageUrls: json['imageUrls'] is List ? (json['imageUrls'] as List).map((e) => e.toString()).toList() : [],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
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
      deposit: json['deposit']?.toString(),
      moveInDate: json['moveInDate']?.toString(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      listedAt: json['listedAt']?.toString(),
      lastConfirmedAt: json['lastConfirmedAt']?.toString(),
      country: json['country']?.toString() ?? 'KE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
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
      'holdingFeePaid': holdingFeePaid,
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
      if (deposit != null) 'deposit': deposit,
      if (moveInDate != null) 'moveInDate': moveInDate,
      'country': country,
    };
  }
}
