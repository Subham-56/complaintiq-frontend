import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../utils/complaint_status.dart';
import 'complaint_image.dart';
import 'complaint_status_chip.dart';
import 'state_feedback.dart';

typedef ComplaintLoader = Future<List<dynamic>> Function();

class ComplaintMapContent extends StatefulWidget {
  const ComplaintMapContent({
    super.key,
    required this.loadComplaints,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyIcon = Icons.map_outlined,
    required this.errorMessage,
  });

  final ComplaintLoader loadComplaints;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final String errorMessage;

  @override
  State<ComplaintMapContent> createState() => _ComplaintMapContentState();
}

class _ComplaintMapContentState extends State<ComplaintMapContent> {
  final MapController _mapController = MapController();
  late Future<List<dynamic>> _future;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _future = widget.loadComplaints();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return StateFeedback(
            icon: Icons.error_outline,
            title: 'Unable to load map',
            message: widget.errorMessage,
          );
        }

        final complaints = (snapshot.data ?? [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .where(_hasValidCoordinates)
            .toList();

        if (complaints.isEmpty) {
          return StateFeedback(
            icon: widget.emptyIcon,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(20.2961, 85.8245),
                  initialZoom: 13,
                  minZoom: 10,
                  maxZoom: 30,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.complaintiq.app',
                  ),
                  MarkerLayer(
                    markers: complaints.map<Marker>((c) {
                      final lat = (c['latitude'] as num).toDouble();
                      final lng = (c['longitude'] as num).toDouble();
                      final status = ComplaintStatus.normalize(
                        c['status']?.toString(),
                      );

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = c),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 38,
                            color: ComplaintStatus.foreground(status),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (_selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selected!['image_url'] != null) ...[
                          ComplaintImage(
                            imageUrl: _selected!['image_url'] as String,
                            height: 110,
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (_selected!['ai_department'] ??
                                        _selected!['issue_type'] ??
                                        '')
                                    .toString(),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            ComplaintStatusChip(
                              status: _selected!['status']?.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selected!['description']?.toString() ?? '',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _selected = null),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _hasValidCoordinates(Map<String, dynamic> complaint) {
    final latitude = complaint['latitude'];
    final longitude = complaint['longitude'];
    if (latitude is! num || longitude is! num) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}