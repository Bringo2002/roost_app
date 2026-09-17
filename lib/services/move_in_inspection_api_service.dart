import 'package:roost_app/models/move_in_inspection.dart';
import 'package:roost_app/services/api_service.dart';

/// Talks to the backend's /api/inspections endpoints. Previously
/// MoveInInspectionPage had no persistence at all -- every inspection
/// lived only in the widget's in-memory state, gone the moment the app
/// was backgrounded and reclaimed. This is the service layer for the
/// server-side persistence that replaces that.
class MoveInInspectionApiService {
  MoveInInspectionApiService._();

  static Future<MoveInInspection> create({
    required int propertyId,
    required List<RoomInspection> rooms,
  }) async {
    final response = await ApiService.post('/api/inspections', {
      'propertyId': propertyId,
      'rooms': rooms.map((r) => r.toJson()).toList(),
    });
    return MoveInInspection.fromJson(response as Map<String, dynamic>);
  }

  /// Doubles as the autosave call -- every parameter is optional and
  /// omitted-if-null, matching the backend's "leave unchanged" update
  /// semantics. Call this after every room, not just once at the end.
  static Future<MoveInInspection> update(
    String id, {
    List<RoomInspection>? rooms,
    String? meterElectricity,
    String? meterWater,
    String? tenantSignature,
    String? landlordSignature,
    bool markComplete = false,
  }) async {
    final body = <String, dynamic>{};
    if (rooms != null) body['rooms'] = rooms.map((r) => r.toJson()).toList();
    if (meterElectricity != null) body['meterElectricity'] = meterElectricity;
    if (meterWater != null) body['meterWater'] = meterWater;
    if (tenantSignature != null) body['tenantSignature'] = tenantSignature;
    if (landlordSignature != null) body['landlordSignature'] = landlordSignature;
    if (markComplete) body['markComplete'] = true;

    final response = await ApiService.put('/api/inspections/$id', body);
    return MoveInInspection.fromJson(response as Map<String, dynamic>);
  }

  static Future<MoveInInspection> get(String id) async {
    final response = await ApiService.get('/api/inspections/$id');
    return MoveInInspection.fromJson(response as Map<String, dynamic>);
  }

  /// The authenticated tenant's own inspections, most recent first --
  /// used both for a "My Inspections" list and to check for an
  /// in-progress inspection on a given property to resume rather than
  /// silently starting a duplicate.
  static Future<List<MoveInInspection>> mine() async {
    final response = await ApiService.get('/api/inspections/mine');
    return (response as List).map((e) => MoveInInspection.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Landlord's view of every inspection filed for one of their
  /// properties. Throws if the caller isn't that property's owner --
  /// enforced server-side, not just hidden client-side.
  static Future<List<MoveInInspection>> forProperty(int propertyId) async {
    final response = await ApiService.get('/api/inspections/property/$propertyId');
    return (response as List).map((e) => MoveInInspection.fromJson(e as Map<String, dynamic>)).toList();
  }
}
