import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:roost_app/models/move_in_inspection.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/pages/search/move_in_inspection_page.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/move_in_inspection_api_service.dart';
import 'package:roost_app/theme/app_colors.dart';

/// A tenant's own move-in inspections, most recent first.
///
/// Replaces what used to be a "Move-in Inspection Wizard" menu item in
/// the profile page that launched with a hardcoded fake property (id 0,
/// "Sample Rental Home") -- completely disconnected from any inspection
/// the tenant might actually be doing. Starting a *new* inspection
/// still happens from the property detail page, where it's already
/// wired to the real property; this page is for resuming or reviewing
/// ones already in progress or completed.
class MyInspectionsPage extends StatefulWidget {
  const MyInspectionsPage({super.key});

  @override
  State<MyInspectionsPage> createState() => _MyInspectionsPageState();
}

class _MyInspectionsPageState extends State<MyInspectionsPage> {
  bool _loading = true;
  String? _error;
  List<MoveInInspection> _inspections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inspections = await MoveInInspectionApiService.mine();
      if (!mounted) return;
      setState(() {
        _inspections = inspections;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your inspections. Check your connection and try again.";
        _loading = false;
      });
    }
  }

  Future<void> _open(MoveInInspection inspection) async {
    if (inspection.completedAt != null) {
      _showReport(inspection);
      return;
    }
    // In-progress -- fetch the real property and hand off to the
    // wizard, which will resume this exact inspection (it checks for
    // an incomplete one matching the property id on open).
    try {
      final json = await ApiService.get('/api/properties/${inspection.propertyId}');
      if (!mounted) return;
      final property = Property.fromJson(json as Map<String, dynamic>);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MoveInInspectionPage(property: property)));
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open this inspection right now")),
        );
      }
    }
  }

  void _showReport(MoveInInspection inspection) {
    final report = inspection.generateReport();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inspection.propertyTitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(report, style: const TextStyle(color: AppColors.grey300, fontSize: 13, height: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Clipboard.setData(ClipboardData(text: report)),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.grey700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Share.share(report, subject: 'Move-in Inspection Report — ${inspection.propertyTitle}'),
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        title: const Text('My Inspections', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey400)),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _inspections.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_outlined, color: AppColors.grey700, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              'No move-in inspections yet',
                              style: TextStyle(color: AppColors.grey400, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Start one from any property\'s detail page',
                              style: TextStyle(color: AppColors.grey600, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.white,
                      backgroundColor: AppColors.grey900,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _inspections.length,
                        itemBuilder: (context, index) => _buildInspectionCard(_inspections[index]),
                      ),
                    ),
    );
  }

  Widget _buildInspectionCard(MoveInInspection inspection) {
    final completed = inspection.completedAt != null;
    return GestureDetector(
      onTap: () => _open(inspection),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.grey800, shape: BoxShape.circle),
              child: Icon(
                completed ? Icons.fact_check_outlined : Icons.pending_actions_outlined,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inspection.propertyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    completed
                        ? 'Completed ${DateFormat('MMM d, yyyy').format(inspection.completedAt!)}'
                        : 'In progress · started ${DateFormat('MMM d, yyyy').format(inspection.createdAt)}',
                    style: TextStyle(color: AppColors.grey500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.grey600, size: 20),
          ],
        ),
      ),
    );
  }
}
