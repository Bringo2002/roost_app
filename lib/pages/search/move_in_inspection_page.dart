import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:roost_app/models/move_in_inspection.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/auth_service.dart';
import 'package:roost_app/services/cloudinary_service.dart';
import 'package:roost_app/services/move_in_inspection_api_service.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/widgets/property_detail/signature_pad_sheet.dart';

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

  // Persistence state -- see MoveInInspectionApiService. _initializing
  // covers the initial "resume or create" round trip; _saveFailed
  // means every subsequent autosave has been failing, worth telling
  // the tenant about since it means their progress isn't actually
  // being recorded despite the wizard working fine locally.
  bool _initializing = true;
  bool _saveFailed = false;
  Timer? _autosaveDebounce;

  final _meterElectricityCtrl = TextEditingController();
  final _meterWaterCtrl = TextEditingController();
  final _picker = ImagePicker();

  // Per-item note controllers — created once per item and reused
  // across rebuilds, preventing the P0 memory leak caused by
  // allocating a new TextEditingController inside itemBuilder.
  late List<List<TextEditingController>> _noteControllers;

  @override
  void initState() {
    super.initState();
    _inspection = MoveInInspection.createNew(
      propertyId: widget.property.id ?? 0,
      propertyTitle: widget.property.title,
      tenantName: 'Tenant',
    );
    _initNoteControllers();
    _loadUserName();
    _initializeServerRecord();
  }

  /// Creates one TextEditingController per inspection item, organized
  /// by room. Called once in initState and again if a server-side
  /// inspection is resumed (which may have different note content).
  void _initNoteControllers() {
    _noteControllers = _inspection.rooms.map((room) {
      return room.items.map((item) {
        return TextEditingController(text: item.notes);
      }).toList();
    }).toList();
  }

  /// Resumes an existing in-progress inspection for this property if
  /// one exists, rather than silently starting a duplicate every time
  /// the tenant reopens the wizard.
  Future<void> _initializeServerRecord() async {
    final propertyId = widget.property.id;
    if (propertyId == null) {
      if (mounted) setState(() { _initializing = false; _saveFailed = true; });
      return;
    }
    try {
      final mine = await MoveInInspectionApiService.mine();
      final resumable = mine.where((i) => i.propertyId == propertyId && i.completedAt == null);
      if (resumable.isNotEmpty) {
        final toResume = resumable.first;
        if (!mounted) return;
        setState(() {
          _inspection = toResume;
          _currentRoomIndex = 0;
          _meterElectricityCtrl.text = toResume.meterElectricity ?? '';
          _meterWaterCtrl.text = toResume.meterWater ?? '';
          _initializing = false;
        });
        // Re-create controllers with resumed content.
        _disposeNoteControllers();
        _initNoteControllers();
        return;
      }

      final created = await MoveInInspectionApiService.create(
        propertyId: propertyId,
        rooms: _inspection.rooms,
      );
      if (!mounted) return;
      setState(() {
        _inspection = created;
        _initializing = false;
      });
    } catch (_) {
      if (mounted) setState(() { _initializing = false; _saveFailed = true; });
    }
  }

  /// Fires an autosave after a discrete action immediately, or after
  /// typing pauses with a short debounce.
  void _autosave({bool immediate = false}) {
    if (_inspection.id == null) return;
    _autosaveDebounce?.cancel();
    if (immediate) {
      _performAutosave();
    } else {
      _autosaveDebounce = Timer(const Duration(milliseconds: 800), _performAutosave);
    }
  }

  Future<void> _performAutosave() async {
    final id = _inspection.id;
    if (id == null) return;
    try {
      await MoveInInspectionApiService.update(id, rooms: _inspection.rooms);
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    }
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

  void _disposeNoteControllers() {
    for (final roomCtrls in _noteControllers) {
      for (final ctrl in roomCtrls) {
        ctrl.dispose();
      }
    }
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _meterElectricityCtrl.dispose();
    _meterWaterCtrl.dispose();
    _disposeNoteControllers();
    super.dispose();
  }

  RoomInspection get _currentRoom => _inspection.rooms[_currentRoomIndex];

  void _nextRoom() {
    HapticFeedback.lightImpact();
    if (_currentRoomIndex < _inspection.rooms.length - 1) {
      setState(() => _currentRoomIndex++);
    } else {
      _inspection.meterElectricity = _meterElectricityCtrl.text.trim().isEmpty
          ? null
          : _meterElectricityCtrl.text.trim();
      _inspection.meterWater = _meterWaterCtrl.text.trim().isEmpty
          ? null
          : _meterWaterCtrl.text.trim();
      setState(() => _showingSummary = true);
    }
    _autosave(immediate: true);
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
      _currentRoom.items[itemIndex].isInspected = true;
    });
    _autosave(immediate: true);
  }

  void _setNotes(int itemIndex, String notes) {
    setState(() {
      _currentRoom.items[itemIndex].notes = notes;
    });
    _autosave();
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
        _autosave(immediate: true);
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

  Future<void> _signAs({required bool isTenant}) async {
    final bytes = await SignaturePadSheet.show(context, signerLabel: isTenant ? 'Tenant' : 'Landlord');
    if (bytes == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await CloudinaryService.uploadImage(
        bytes,
        fileName: '${isTenant ? 'tenant' : 'landlord'}_signature_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (url != null && mounted) {
        setState(() {
          if (isTenant) {
            _inspection.tenantSignature = url;
          } else {
            _inspection.landlordSignature = url;
          }
        });
        _autosave(immediate: true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save signature')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Report generation (de-duplicated) ─────────────────────────────────────

  /// Finalizes the inspection (marks complete, saves to server) and
  /// returns the generated report text. Shared by _shareReport and
  /// _copyReport to eliminate the 67 lines of duplication.
  Future<String> _finalizeAndGenerateReport() async {
    _inspection.completedAt = DateTime.now();
    _inspection.meterElectricity = _meterElectricityCtrl.text.trim().isEmpty
        ? null
        : _meterElectricityCtrl.text.trim();
    _inspection.meterWater = _meterWaterCtrl.text.trim().isEmpty
        ? null
        : _meterWaterCtrl.text.trim();

    final id = _inspection.id;
    if (id != null) {
      try {
        await MoveInInspectionApiService.update(
          id,
          rooms: _inspection.rooms,
          meterElectricity: _inspection.meterElectricity,
          meterWater: _inspection.meterWater,
          markComplete: true,
        );
      } catch (_) {
        // Still generate the report locally even if the final save
        // failed — the tenant's evidence is valuable regardless.
      }
    }

    return _inspection.generateReport();
  }

  Future<void> _shareReport() async {
    final report = await _finalizeAndGenerateReport();
    if (!mounted) return;
    await Share.share(report, subject: 'Move-in Inspection Report — ${widget.property.title}');
  }

  Future<void> _copyReport() async {
    final report = await _finalizeAndGenerateReport();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deposit Protection Report copied to clipboard!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: _initializing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey400),
                    )
                  : Tooltip(
                      message: _saveFailed
                          ? "Not saved — check your connection. Your work stays on this screen until you retry."
                          : 'Saved',
                      child: Icon(
                        _saveFailed ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                        color: _saveFailed ? AppColors.grey400 : AppColors.grey600,
                        size: 18,
                      ),
                    ),
            ),
          ),
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
                    ? AppColors.grey300
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
            itemBuilder: (_, i) => _InspectionItemCard(
              item: room.items[i],
              noteController: _noteControllers[_currentRoomIndex][i],
              uploading: _uploading,
              onConditionChanged: (c) => _setCondition(i, c),
              onNotesChanged: (v) => _setNotes(i, v),
              onAttachPhoto: () => _attachPhoto(i),
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary View ──────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final counts = _inspection.conditionCounts;

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Property info header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.white.withAlpha(10),
                AppColors.white.withAlpha(4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
                style: const TextStyle(color: AppColors.grey400, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Inspected on ${DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now())}',
                style: const TextStyle(color: AppColors.grey500, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Stats row — uses conditionCounts (single pass)
        Row(
          children: [
            _SummaryStat(label: 'Total', value: '${_inspection.totalItems}'),
            const SizedBox(width: 8),
            _SummaryStat(label: 'Good', value: '${counts.good}', icon: Icons.check_circle_outline),
            const SizedBox(width: 8),
            _SummaryStat(label: 'Wear', value: '${counts.wear}', icon: Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _SummaryStat(label: 'Damaged', value: '${counts.damaged}', icon: Icons.error_outline),
          ],
        ),

        const SizedBox(height: 20),

        // Meter readings section
        _buildSectionHeader('METER READINGS'),
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
        _buildSectionHeader('ROOM BREAKDOWN'),
        const SizedBox(height: 10),
        for (final room in _inspection.rooms) ...[
          _RoomSummaryCard(room: room),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 24),

        // Digital sign-off
        _buildSectionHeader('SIGN-OFF'),
        const SizedBox(height: 10),
        _SignatureRow(
          label: 'Tenant signature',
          signatureUrl: _inspection.tenantSignature,
          onTap: () => _signAs(isTenant: true),
        ),
        const SizedBox(height: 8),
        _SignatureRow(
          label: 'Landlord signature',
          signatureUrl: _inspection.landlordSignature,
          onTap: () => _signAs(isTenant: false),
        ),

        const SizedBox(height: 20),

        // Transparency note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This report serves as evidence of property condition at move-in. '
                  'Share it with your host for mutual agreement.',
                  style: TextStyle(color: AppColors.grey400, fontSize: 11),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.grey500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.grey500,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
                const SizedBox(width: 10),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey700),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: _copyReport,
                    icon: const Icon(Icons.copy_rounded, color: AppColors.white, size: 18),
                    tooltip: 'Copy to clipboard',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _shareReport,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share Report'),
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
                        Flexible(
                          child: Text(
                            _currentRoomIndex < _inspection.rooms.length - 1
                                ? 'Next: ${_inspection.rooms[_currentRoomIndex + 1].roomName}'
                                : 'View Summary',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
      labelStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
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
}

// ──────────────────────────────────────────────────────────────────────────────
// Inspection item card (extracted from 184-line _buildItemCard method)
// ──────────────────────────────────────────────────────────────────────────────

class _InspectionItemCard extends StatelessWidget {
  const _InspectionItemCard({
    required this.item,
    required this.noteController,
    required this.uploading,
    required this.onConditionChanged,
    required this.onNotesChanged,
    required this.onAttachPhoto,
  });

  final InspectionItem item;
  final TextEditingController noteController;
  final bool uploading;
  final ValueChanged<ItemCondition> onConditionChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onAttachPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: switch (item.condition) {
            ItemCondition.damaged => AppColors.grey500,
            ItemCondition.minorWear => AppColors.grey700,
            _ => AppColors.border,
          },
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

          // Condition toggles — InkWell instead of GestureDetector
          Row(
            children: ItemCondition.values.map((c) {
              final selected = item.condition == c;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: c != ItemCondition.notApplicable ? 6 : 0,
                  ),
                  child: Material(
                    color: selected ? AppColors.white.withAlpha(30) : AppColors.black,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onConditionChanged(c),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? AppColors.white : AppColors.border,
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
                                color: selected ? AppColors.white : AppColors.grey500,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
              controller: noteController,
              onChanged: onNotesChanged,
              style: const TextStyle(color: AppColors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
                hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 13),
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

          // Photo attachment — InkWell with proper tap target
          const SizedBox(height: 10),
          Row(
            children: [
              Material(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: uploading ? null : onAttachPhoto,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          uploading ? Icons.hourglass_top : Icons.camera_alt_outlined,
                          color: AppColors.grey400,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          uploading ? 'Uploading...' : 'Add Photo',
                          style: const TextStyle(color: AppColors.grey300, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.photoUrls.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.grey800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.photoUrls.length} photo${item.photoUrls.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: AppColors.grey300, fontSize: 11, fontWeight: FontWeight.bold),
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
                  child: CachedNetworkImage(
                    imageUrl: item.photoUrls[i],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    memCacheWidth: 112,
                    memCacheHeight: 112,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.grey800,
                    ),
                    errorWidget: (_, __, ___) => Container(
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
}

// ──────────────────────────────────────────────────────────────────────────────
// Summary stat widget
// ──────────────────────────────────────────────────────────────────────────────

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
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
            if (icon != null) ...[
              Icon(icon, color: AppColors.white, size: 16),
              const SizedBox(height: 2),
            ],
            Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.grey500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Room summary card
// ──────────────────────────────────────────────────────────────────────────────

class _RoomSummaryCard extends StatelessWidget {
  const _RoomSummaryCard({required this.room});

  final RoomInspection room;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: switch (room.issueCount) {
            > 0 => AppColors.grey500,
            _ when room.wearCount > 0 => AppColors.grey600,
            _ => AppColors.border,
          },
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
              _buildStatusPill(),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: room.items.map((item) {
              return Text(
                '${item.condition.emoji} ${item.name}',
                style: const TextStyle(color: AppColors.grey400, fontSize: 11),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final (String text, Color bg, Color fg) = switch (room.issueCount) {
      > 0 => (
          '${room.issueCount} issue${room.issueCount > 1 ? 's' : ''}',
          AppColors.white,
          AppColors.black,
        ),
      _ when room.wearCount > 0 => (
          '${room.wearCount} wear',
          AppColors.grey800,
          AppColors.grey300,
        ),
      _ => ('All Good', AppColors.grey900, AppColors.grey500),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Signature row
// ──────────────────────────────────────────────────────────────────────────────

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.label,
    required this.signatureUrl,
    required this.onTap,
  });

  final String label;
  final String? signatureUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final signed = signatureUrl != null && signatureUrl!.isNotEmpty;
    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: signed ? AppColors.white : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                signed ? Icons.check_circle : Icons.draw_outlined,
                color: signed ? AppColors.white : AppColors.grey400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                signed ? 'Signed · tap to redo' : 'Tap to sign',
                style: TextStyle(color: signed ? AppColors.grey400 : AppColors.grey500, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
