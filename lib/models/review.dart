import 'user.dart';

class Review {
  final int id;
  final int propertyId;
  final User reviewer;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.propertyId,
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as num?)?.toInt() ?? 0,
      propertyId: (json['propertyId'] as num?)?.toInt() ?? 0,
      reviewer: json['reviewer'] != null 
          ? User.fromJson(json['reviewer']) 
          : User(id: 0, name: 'Unknown', email: '', role: ''),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
