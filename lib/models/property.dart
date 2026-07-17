import 'user.dart';

class Property {
  final int? id;
  final String title;
  final String description;
  final String location;
  final double price;
  final int bedrooms;
  final String type;
  final String landlordPhone;
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

  Property({
    this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    required this.bedrooms,
    required this.type,
    required this.landlordPhone,
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
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] != null ? (json['id'] as num).toInt() : null,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      bedrooms: json['bedrooms'] ?? 0,
      type: json['type'] ?? 'all',
      landlordPhone: json['landlordPhone'] ?? '',
      available: json['available'] ?? true,
      imageUrl: json['imageUrl'],
      verified: json['verified'] ?? false,
      holdingFeePaid: json['holdingFeePaid'] ?? false,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
      imageUrls: json['imageUrls'] != null ? List<String>.from(json['imageUrls']) : [],
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      videoUrl: json['videoUrl'],
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
      'available': available,
      'imageUrl': imageUrl,
      'verified': verified,
      'holdingFeePaid': holdingFeePaid,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
    };
  }
}
