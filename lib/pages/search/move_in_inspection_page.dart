import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/models/move_in_inspection.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/cloudinary_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// A full-screen room-by-room Move-in Inspection wizard allowing tenants
/// to document property condition, attach photo evidence, record meter
/// readings, and generate a shareable Deposit Protection Report.
class MoveInInspectionPage extends StatefulWidget {
  const MoveInInspectionPage({super.key, required this.property});

  final Property property;

  @override
  State<MoveInInspectionPage> createState() => _MoveInInspectionPageState();
}

class _MoveInInspectionPageState extends State<MoveInInspectionPage> {
  late MoveInInspection _inspection;
  int _currentRoomIndex = 0;
  bool _showingSummary = false;
  bool _uploading = false;

  final _meterElectricityCtrl = TextEditingController();
  final _meterWaterCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _inspection = MoveInInspection.createNew(
      propertyId: widget.property.id ?? 0,
      propertyTitle: widget.property.title,
      tenantName: 'Tenant',
    );
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getUserName();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() {
        _inspection = MoveInInspection(
          id: _inspection.id,
          propertyId: _inspection.propertyId,
          propertyTitle: _inspection.propertyTitle,
          tenantName: name,
          landlordName: _inspection.landlordName,
          createdAt: _inspection.createdAt,
          completedAt: _inspection.completedAt,
          rooms: _inspection.rooms,
          tenantSignature: _inspection.tenantSignature,
          landlordSignature: _inspection.landlordSignature,
          meterElectricity: _inspection.meterElectricity,
          meterWater: _inspection.meterWater,
        );
      });
    }
  }

  @override
  void dispose() {
    _meterElectricityCtrl.dispose();
    _meterWaterCtrl.dispose();
    super.dispose();
  }

  RoomInspection get _currentRoom => _inspection.rooms[_currentRoomIndex];

  void _nextRoom() {
    HapticFeedback.lightImpact();
    if (_currentRoomIndex < _inspection.rooms.length - 1) {
      setState(() => _currentRoomIndex++);
    } else {
      // Save meter readings and show summary
      _inspection.meterElectricity = _meterElectricityCtrl.text.trim().isEmpty
          ? null
          : _meterElectricityCtrl.text.trim();
      _inspection.meterWater = _meterWaterCtrl.text.trim().isEmpty
          ? null
          : _meterWaterCtrl.text.trim();
      setState(() => _showingSummary = true);
    }
  }

  void _prevRoom() {
    HapticFeedback.lightImpact();
    if (_showingSummary) {
      setState(() => _showingSummary = false);
    } else if (_currentRoomIndex > 0) {
      setState(() => _currentRoomIndex--);
    }
  }

  void _setCondition(int itemIndex, ItemCondition condition) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentRoom.items[itemIndex].condition = condition;
    });
  }

  void _setNotes(int itemIndex, String notes) {
    setState(() {
      _currentRoom.items[itemIndex].notes = notes;
    });
  }

  Future<void> _attachPhoto(int itemIndex) async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes, fileName: 'inspection_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (url != null && mounted) {
        setState(() {
          _currentRoom.items[itemIndex].photoUrls.add(url);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _copyReport() {
    _inspection.completedAt = DateTime.now();
    _inspection.meterElectricity = _meterElectricityCtrl.text.trim().isEmpty
        ? null
        : _meterElectricityCtrl.text.trim();
    _inspection.meterWater = _meterWaterCtrl.text.trim().isEmpty
        ? null
        : _meterWaterCtrl.text.trim();
    final report = _inspection.generateReport();
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deposit Protection Report copied to clipboard!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () {
            if (_showingSummary) {
              _prevRoom();
            } else if (_currentRoomIndex > 0) {
              _prevRoom();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _showingSummary ? 'Inspection Summary' : _currentRoom.roomName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_showingSummary)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${_currentRoomIndex + 1} / ${_inspection.rooms.length}',
                    style: const TextStyle(
                      color: AppColors.grey300,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _showingSummary ? _buildSummary() : _buildRoomInspection(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Room Progress Bar ─────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_inspection.rooms.length, (i) {
          final isActive = i == _currentRoomIndex;
          final isDone = i < _currentRoomIndex;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < _inspection.rooms.length - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDone
                    ? const Color(0xFF10B981)
                    : isActive
                        ? AppColors.white
                        : AppColors.grey700,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Room Inspection View ──────────────────────────────────────────────────
  Widget _buildRoomInspection() {
    final room = _currentRoom;

    return Column(
      children: [
        const SizedBox(height: 8),
        _buildProgressBar(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            physics: const BouncingScrollPhysics(),
            itemCount: room.items.length,
            itemBuilder: (_, i) => _buildItemCard(room.items[i], i),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(InspectionItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.condition == ItemCondition.damaged
              ? Colors.redAccent.withValues(alpha: 0.5)
              : item.condition == ItemCondition.minorWear
                  ? Colors.amber.withValues(alpha: 0.5)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name
          Text(
            item.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Condition toggles
          Row(
            children: ItemCondition.values.map((c) {
              final selected = item.condition == c;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _setCondition(index, c),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: c != ItemCondition.notApplicable ? 6 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _conditionColor(c).withValues(alpha: 0.2) : AppColors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _conditionColor(c) : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          c.label,
                          style: TextStyle(
                            color: selected ? _conditionColor(c) : AppColors.grey500,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Notes field (shown if not Good)
          if (item.condition != ItemCondition.good &&
              item.condition != ItemCondition.notApplicable) ...[
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => _setNotes(index, v),
              controller: TextEditingController(text: item.notes)
                ..selection = TextSelection.collapsed(offset: item.notes.length),
              style: const TextStyle(color: AppColors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: AppColors.black,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.grey400),
                ),
              ),
            ),
          ],

          // Photo attachment
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: _uploading ? null : () => _attachPhoto(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _uploading ? Icons.hourglass_top : Icons.camera_alt_outlined,
                        color: AppColors.grey400,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _uploading ? 'Uploading...' : 'Add Photo',
                        style: const TextStyle(color: AppColors.grey300, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.photoUrls.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.photoUrls.length} photo${item.photoUrls.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          // Photo thumbnails
          if (item.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.photoUrls[i],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.grey800,
                      child: const Icon(Icons.broken_image, color: AppColors.grey500, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Summary View ──────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final totalItems = _inspection.totalItems;
    final goodCount = _inspection.rooms.expand((r) => r.items).where((i) => i.condition == ItemCondition.good).length;
    final wearCount = _inspection.rooms.expand((r) => r.items).where((i) => i.condition == ItemCondition.minorWear).length;
    final dmgCount = _inspection.totalIssues;

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Property info header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1C2C), Color(0xFF2A2A36)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.property.title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.property.location,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Inspected on ${DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now())}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Stats row
        Row(
          children: [
            _buildSummaryStat('Total', '$totalItems', AppColors.white),
            const SizedBox(width: 8),
            _buildSummaryStat('Good', '$goodCount', const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _buildSummaryStat('Wear', '$wearCount', Colors.amber),
            const SizedBox(width: 8),
            _buildSummaryStat('Damaged', '$dmgCount', Colors.redAccent),
          ],
        ),

        const SizedBox(height: 20),

        // Meter readings section
        Text(
          'METER READINGS',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _meterElectricityCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.white),
                decoration: _meterDecoration('⚡ Electricity Meter'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _meterWaterCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.white),
                decoration: _meterDecoration('💧 Water Meter'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Room-by-room breakdown
        Text(
          'ROOM BREAKDOWN',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        for (final room in _inspection.rooms) ...[
          _buildRoomSummaryCard(room),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 20),

        // Transparency note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This report serves as evidence of property condition at move-in. '
                  'Share it with your host for mutual agreement.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSummaryCard(RoomInspection room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: room.issueCount > 0
              ? Colors.redAccent.withValues(alpha: 0.4)
              : room.wearCount > 0
                  ? Colors.amber.withValues(alpha: 0.4)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(room.roomIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.roomName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (room.issueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${room.issueCount} issue${room.issueCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else if (room.wearCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${room.wearCount} wear',
                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'All Good',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: room.items.map((item) {
              return Text(
                '${item.condition.emoji} ${item.name}',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: _showingSummary
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _prevRoom,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.grey700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _copyReport,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (_currentRoomIndex > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _prevRoom,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.grey700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: _currentRoomIndex > 0 ? 2 : 1,
                  child: ElevatedButton(
                    onPressed: _nextRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentRoomIndex < _inspection.rooms.length - 1
                              ? 'Next: ${_inspection.rooms[_currentRoomIndex + 1].roomName}'
                              : 'View Summary',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  InputDecoration _meterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
      filled: true,
      fillColor: AppColors.black,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey400),
      ),
    );
  }

  Color _conditionColor(ItemCondition c) {
    switch (c) {
      case ItemCondition.good:
        return const Color(0xFF10B981);
      case ItemCondition.minorWear:
        return Colors.amber;
      case ItemCondition.damaged:
        return Colors.redAccent;
      case ItemCondition.notApplicable:
        return AppColors.grey500;
    }
  }
}
