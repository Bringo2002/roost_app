enum ItemCondition {
  good,
  minorWear,
  damaged,
  notApplicable,
}

extension ItemConditionX on ItemCondition {
  String get label {
    switch (this) {
      case ItemCondition.good:
        return 'Good';
      case ItemCondition.minorWear:
        return 'Minor Wear';
      case ItemCondition.damaged:
        return 'Damaged';
      case ItemCondition.notApplicable:
        return 'N/A';
    }
  }

  String get emoji {
    switch (this) {
      case ItemCondition.good:
        return '✅';
      case ItemCondition.minorWear:
        return '⚠️';
      case ItemCondition.damaged:
        return '❌';
      case ItemCondition.notApplicable:
        return '➖';
    }
  }
}

class InspectionItem {
  final String name;
  ItemCondition condition;
  String notes;
  List<String> photoUrls;
  bool isInspected; // Added to track if this item has been reviewed

  InspectionItem({
    required this.name,
    this.condition = ItemCondition.good,
    this.notes = '',
    List<String>? photoUrls,
    this.isInspected = false,
  }) : photoUrls = photoUrls ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'condition': condition.name,
      'notes': notes,
      'photoUrls': photoUrls,
      'isInspected': isInspected,
    };
  }

  factory InspectionItem.fromJson(Map<String, dynamic> json) {
    return InspectionItem(
      name: json['name'] as String,
      condition: ItemCondition.values.firstWhere(
        (e) => e.name == json['condition'],
        orElse: () => ItemCondition.good,
      ),
      notes: json['notes'] as String? ?? '',
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      isInspected: json['isInspected'] as bool? ?? false,
    );
  }
}

class RoomInspection {
  final String roomName;
  final String roomIcon;
  List<InspectionItem> items;

  RoomInspection({
    required this.roomName,
    required this.roomIcon,
    required this.items,
  });

  bool get isComplete => items.every((item) => item.isInspected);
  int get issueCount => items.where((item) => item.condition == ItemCondition.damaged).length;
  int get wearCount => items.where((item) => item.condition == ItemCondition.minorWear).length;

  Map<String, dynamic> toJson() {
    return {
      'roomName': roomName,
      'roomIcon': roomIcon,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  factory RoomInspection.fromJson(Map<String, dynamic> json) {
    return RoomInspection(
      roomName: json['roomName'] as String,
      roomIcon: json['roomIcon'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => InspectionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MoveInInspection {
  String? id;
  final int propertyId;
  final String propertyTitle;
  final String tenantName;
  String? landlordName;
  final DateTime createdAt;
  DateTime? completedAt;
  List<RoomInspection> rooms;
  String? tenantSignature;
  String? landlordSignature;
  String? meterElectricity;
  String? meterWater;

  MoveInInspection({
    this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.tenantName,
    this.landlordName,
    required this.createdAt,
    this.completedAt,
    required this.rooms,
    this.tenantSignature,
    this.landlordSignature,
    this.meterElectricity,
    this.meterWater,
  });

  bool get isComplete =>
      rooms.every((room) => room.isComplete) &&
      tenantSignature != null &&
      landlordSignature != null;

  int get totalIssues => rooms.fold(0, (sum, room) => sum + room.issueCount);

  int get totalItems => rooms.fold(0, (sum, room) => sum + room.items.length);

  int get inspectedItems => rooms.fold(
      0, (sum, room) => sum + room.items.where((item) => item.isInspected).length);

  double get completionPercentage => totalItems == 0 ? 0 : inspectedItems / totalItems;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'tenantName': tenantName,
      'landlordName': landlordName,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'rooms': rooms.map((e) => e.toJson()).toList(),
      'tenantSignature': tenantSignature,
      'landlordSignature': landlordSignature,
      'meterElectricity': meterElectricity,
      'meterWater': meterWater,
    };
  }

  factory MoveInInspection.fromJson(Map<String, dynamic> json) {
    return MoveInInspection(
      id: json['id'] as String?,
      propertyId: json['propertyId'] as int,
      propertyTitle: json['propertyTitle'] as String,
      tenantName: json['tenantName'] as String,
      landlordName: json['landlordName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      rooms: (json['rooms'] as List<dynamic>?)
              ?.map((e) => RoomInspection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tenantSignature: json['tenantSignature'] as String?,
      landlordSignature: json['landlordSignature'] as String?,
      meterElectricity: json['meterElectricity'] as String?,
      meterWater: json['meterWater'] as String?,
    );
  }

  static MoveInInspection createNew({
    required int propertyId,
    required String propertyTitle,
    required String tenantName,
  }) {
    return MoveInInspection(
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      tenantName: tenantName,
      createdAt: DateTime.now(),
      rooms: [
        RoomInspection(
          roomName: 'Living Room',
          roomIcon: '🛋️',
          items: [
            InspectionItem(name: 'Walls & Paint'),
            InspectionItem(name: 'Flooring'),
            InspectionItem(name: 'Windows & Curtains'),
            InspectionItem(name: 'Light Fixtures'),
            InspectionItem(name: 'Electrical Outlets'),
            InspectionItem(name: 'Door & Lock'),
          ],
        ),
        RoomInspection(
          roomName: 'Kitchen',
          roomIcon: '🍳',
          items: [
            InspectionItem(name: 'Sink & Plumbing'),
            InspectionItem(name: 'Countertops'),
            InspectionItem(name: 'Cabinets & Shelves'),
            InspectionItem(name: 'Stove/Cooktop'),
            InspectionItem(name: 'Exhaust/Ventilation'),
            InspectionItem(name: 'Flooring'),
          ],
        ),
        RoomInspection(
          roomName: 'Master Bedroom',
          roomIcon: '🛏️',
          items: [
            InspectionItem(name: 'Walls & Paint'),
            InspectionItem(name: 'Flooring'),
            InspectionItem(name: 'Windows & Curtains'),
            InspectionItem(name: 'Built-in Wardrobes'),
            InspectionItem(name: 'Light Fixtures'),
            InspectionItem(name: 'Door & Lock'),
          ],
        ),
        RoomInspection(
          roomName: 'Bathroom',
          roomIcon: '🚿',
          items: [
            InspectionItem(name: 'Toilet'),
            InspectionItem(name: 'Shower/Bathtub'),
            InspectionItem(name: 'Sink & Mirror'),
            InspectionItem(name: 'Tiles & Grouting'),
            InspectionItem(name: 'Plumbing (Hot/Cold)'),
            InspectionItem(name: 'Ventilation'),
          ],
        ),
        RoomInspection(
          roomName: 'Utility & Meters',
          roomIcon: '⚡',
          items: [
            InspectionItem(name: 'Main Door & Lock'),
            InspectionItem(name: 'Electricity Meter'),
            InspectionItem(name: 'Water Meter'),
            InspectionItem(name: 'Circuit Breaker'),
            InspectionItem(name: 'Fire Safety Equipment'),
          ],
        ),
      ],
    );
  }

  String generateReport() {
    final dateStr =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('🏠 MOVE-IN INSPECTION REPORT');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Property: $propertyTitle');
    buffer.writeln('Tenant: $tenantName');
    buffer.writeln('Date: $dateStr');
    buffer.writeln();

    for (final room in rooms) {
      buffer.writeln('${room.roomIcon} ${room.roomName.toUpperCase()}');
      for (final item in room.items) {
        final conditionLabel = item.condition.label;
        final notesPart = item.notes.isNotEmpty ? ': ${item.notes}' : '';
        buffer.writeln('  ${item.condition.emoji} ${item.name} — $conditionLabel$notesPart');
      }
      buffer.writeln();
    }

    buffer.writeln('📊 SUMMARY');
    int goodCount = 0;
    int minorWearCount = 0;
    int damagedCount = 0;

    for (final room in rooms) {
      for (final item in room.items) {
        if (item.condition == ItemCondition.good) {
          goodCount++;
        } else if (item.condition == ItemCondition.minorWear) {
          minorWearCount++;
        } else if (item.condition == ItemCondition.damaged) {
          damagedCount++;
        }
      }
    }

    buffer.writeln('Total Items: $totalItems | Good: $goodCount | Minor Wear: $minorWearCount | Damaged: $damagedCount');
    
    final elec = meterElectricity ?? 'N/A';
    final water = meterWater ?? 'N/A';
    buffer.writeln('Meter Readings: Electricity: $elec | Water: $water');
    buffer.writeln();

    final tSign = tenantSignature != null ? tenantName : 'Pending';
    final lSign = landlordSignature != null ? (landlordName ?? 'Landlord') : 'Pending';
    buffer.writeln('✍️ Signed by: $tSign & $lSign');
    buffer.writeln('Generated via Roost App 📱');

    return buffer.toString().trimRight();
  }
}
