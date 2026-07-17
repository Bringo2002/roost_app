import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/models/property.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<dynamic> _applications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.get('/api/applications/my');
      setState(() {
        _applications = list as List;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Applications', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadApplications,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : _applications.isEmpty
                  ? const Center(
                      child: Text(
                        'You have not submitted any applications yet',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.grey[900],
                      onRefresh: _loadApplications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final app = _applications[index];
                          final propertyJson = app['property'];
                          final property = Property.fromJson(propertyJson);
                          final status = app['status'] ?? 'PENDING';
                          final dateStr = app['createdAt'] != null
                              ? DateFormat('dd MMM yyyy, h:mm a').format(DateTime.parse(app['createdAt']))
                              : '';

                          return Card(
                            color: Colors.grey[900],
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            property.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: status == 'APPROVED'
                                                ? Colors.green.withOpacity(0.2)
                                                : status == 'REJECTED'
                                                    ? Colors.red.withOpacity(0.2)
                                                    : Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: status == 'APPROVED'
                                                  ? Colors.green
                                                  : status == 'REJECTED'
                                                      ? Colors.red
                                                      : Colors.amber,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      property.location,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                    ),
                                    const Divider(color: Colors.white10, height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Submitted on', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                            const SizedBox(height: 2),
                                            Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Rent', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                            const SizedBox(height: 2),
                                            Text(
                                              'KES ${NumberFormat('#,##0').format(property.price)}/mo',
                                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
