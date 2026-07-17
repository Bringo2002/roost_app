import 'package:flutter/material.dart';
import 'package:roost_app/models/property.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/favorites_service.dart';
import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Property> _savedProperties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      final favoriteIds = await FavoritesService.getFavoriteIds();
      if (favoriteIds.isEmpty) {
        setState(() {
          _savedProperties = [];
          _loading = false;
        });
        return;
      }

      // Fetch all properties and filter to saved ones
      final jsonList = await ApiService.get('/api/properties');
      final allProperties = (jsonList as List).map((j) => Property.fromJson(j)).toList();
      setState(() {
        _savedProperties = allProperties.where((p) => p.id != null && favoriteIds.contains(p.id)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeFavorite(Property property) async {
    if (property.id != null) {
      await FavoritesService.remove(property.id!);
      _loadSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_savedProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, color: Colors.grey[700], size: 64),
            const SizedBox(height: 16),
            Text(
              'No saved properties',
              style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on any property to save it',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.grey[900],
      onRefresh: _loadSaved,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 80),
        itemCount: _savedProperties.length,
        itemBuilder: (context, index) {
          final property = _savedProperties[index];
          return Dismissible(
            key: Key('saved-${property.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            onDismissed: (_) => _removeFavorite(property),
            child: _buildPropertyCard(property),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
        );
        _loadSaved(); // Refresh in case favorites changed
      },
      child: Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 110,
              height: 110,
              child: property.imageUrl != null && property.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: property.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[850],
                        child: Icon(Icons.home_outlined, color: Colors.grey[700], size: 32),
                      ),
                    )
                  : Container(
                      color: Colors.grey[850],
                      child: Icon(Icons.home_outlined, color: Colors.grey[700], size: 32),
                    ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey[600], size: 13),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            property.location,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KES ${NumberFormat('#,##0').format(property.price)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
