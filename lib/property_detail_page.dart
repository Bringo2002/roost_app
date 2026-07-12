import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailPage extends StatelessWidget {
  final dynamic property;

  const PropertyDetailPage({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Property Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // title
            Text(
              property['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // location
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text(
                  property['location'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 15),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // price
            Text(
              'KES ${property['price'].toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // type chip + bedrooms
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    property['type'].toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.bed, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${property['bedrooms']} bedroom',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // availability
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: property['available'] ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  property['available'] ? 'Available now' : 'Not available',
                  style: TextStyle(
                    color: property['available'] ? Colors.green : Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.grey, height: 40),

            // contact button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final phone = property['landlordPhone'];
                  if (phone != null) {
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                },
                child: const Text(
                  'Contact Landlord',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
