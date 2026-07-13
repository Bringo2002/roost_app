import 'user.dart';
import 'property.dart';

class Application {
  final int id;
  final Property property;
  final User applicant;
  final String fullName;
  final String nationalId;
  final String employmentStatus;
  final double monthlyIncome;
  final String status;
  final DateTime createdAt;

  Application({
    required this.id,
    required this.property,
    required this.applicant,
    required this.fullName,
    required this.nationalId,
    required this.employmentStatus,
    required this.monthlyIncome,
    required this.status,
    required this.createdAt,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      id: (json['id'] as num?)?.toInt() ?? 0,
      property: json['property'] != null 
          ? Property.fromJson(json['property']) 
          : Property(title: '', description: '', location: '', price: 0.0, bedrooms: 1, type: '', landlordPhone: '', available: false),
      applicant: json['applicant'] != null 
          ? User.fromJson(json['applicant']) 
          : User(id: 0, name: 'Unknown', email: '', role: ''),
      fullName: json['fullName'] ?? '',
      nationalId: json['nationalId'] ?? '',
      employmentStatus: json['employmentStatus'] ?? '',
      monthlyIncome: (json['monthlyIncome'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
