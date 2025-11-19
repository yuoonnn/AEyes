import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

class LocationHistoryMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? timestamp;

  const LocationHistoryMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.timestamp,
  });

  @override
  State<LocationHistoryMapScreen> createState() =>
      _LocationHistoryMapScreenState();
}

class _LocationHistoryMapScreenState extends State<LocationHistoryMapScreen> {
  final MapController _mapController = MapController();

  static const String _mapboxApiKey =
      'pk.eyJ1IjoiY2hyaXNzZWdncyIsImEiOiJjbWh4aW4wbGkwMXA4MnFzaHVjaGc3NDgwIn0.I51_0mt0LivtIciiYF9jSw';

  String get _mapboxTileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxApiKey';

  @override
  void initState() {
    super.initState();
    // Ensure the map centers after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(
        LatLng(widget.latitude, widget.longitude),
        15.0,
      );
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _formattedTimestamp() {
    final ts = widget.timestamp;
    if (ts == null) return 'Timestamp unavailable';
    return '${ts.toLocal()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(
                LatLng(widget.latitude, widget.longitude),
                15.0,
              );
            },
            tooltip: 'Center on this point',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.latitude, widget.longitude),
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapboxTileUrl,
                additionalOptions: {
                  'accessToken': _mapboxApiKey,
                },
                userAgentPackageName: 'com.example.aeyesUserApp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitude, widget.longitude),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: AppTheme.error,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: AppTheme.elevationMedium,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.borderRadiusMD,
              ),
              child: Padding(
                padding: AppTheme.paddingMD,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_history,
                          color: AppTheme.primaryGreen,
                        ),
                        SizedBox(width: AppTheme.spacingSM),
                        Expanded(
                          child: Text(
                            'Recorded Location',
                            style: AppTheme.textStyleTitle.copyWith(
                              fontWeight: AppTheme.fontWeightBold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingSM),
                    if (widget.address != null &&
                        widget.address!.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: AppTheme.spacingSM,
                        ),
                        child: Text(
                          widget.address!,
                          style: AppTheme.textStyleBody,
                        ),
                      ),
                    Text(
                      'Latitude: ${widget.latitude.toStringAsFixed(6)}',
                      style: AppTheme.textStyleBody,
                    ),
                    Text(
                      'Longitude: ${widget.longitude.toStringAsFixed(6)}',
                      style: AppTheme.textStyleBody,
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      _formattedTimestamp(),
                      style: AppTheme.textStyleCaption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

