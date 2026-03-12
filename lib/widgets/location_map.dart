import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crowdpass/services/location_service.dart';
import 'package:crowdpass/models/location.dart';

import 'package:crowdpass/widgets/debounced_search_bar.dart';
import 'package:crowdpass/widgets/round_icon_button.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    this.location,
    this.onBoundsChanged,
    this.onLocationChanged,
  });

  final Location? location;
  final Function(Location location)? onLocationChanged;
  final Function(LatLngBounds bounds, LatLng center)? onBoundsChanged;

  @override
  State<StatefulWidget> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final MapController _mapController = MapController();
  Location? _location;
  bool _isMapMoved = false;
  Timer? _mapMovedTimer;

  void _showErrorDialog({String? title, String? message, List<Widget>? actions}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title ?? 'Error'),
          content: Text(message ?? 'An unknown error occurred.'),
          actions: [
            if (actions != null) ...actions,
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMapsApp() async {
    if (_location == null) return;
    final lat = _location!.latitude;
    final lon = _location!.longitude;
    final zoom = _mapController.camera.zoom;
    Uri? mapsUri;

    try {
      if (await canLaunchUrl(Uri.parse('maps:'))) {
        mapsUri = Uri.parse('maps://?ll=$lat,$lon&z=$zoom');
      } else if (await canLaunchUrl(Uri.parse('geo:'))) {
        mapsUri = Uri.parse('geo:$lat,$lon?z=$zoom');
      } else if (await canLaunchUrl(Uri.parse('comgooglemaps:'))) {
        mapsUri = Uri.parse('comgooglemaps://?center=$lat,$lon&zoom=$zoom');
      } else if (await canLaunchUrl(Uri.parse('waze:'))) {
        mapsUri = Uri.parse('waze://?ll=$lat,$lon&z=$zoom');
      } else {
        throw 'No maps app found.';
      }
      await launchUrl(mapsUri);
    } catch (error) {
      _showErrorDialog(
        title: 'Failed to Open Maps',
        message: error.toString(),
      );
    }
  }

  void _setLocation(Location location) {
    _mapController.move(location.latLng, location.suggestedZoom);
    _mapController.rotate(0.0);

    if (location.hasBounds) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: location.latLngBounds!,
        padding: const EdgeInsets.all(16),
      ));
    }

    setState(() {
      _location = location;
      _isMapMoved = false;
    });

    if (location != widget.location) {
      widget.onLocationChanged?.call(location);
    }
  }

  Future<List<Location>> _searchLocation(String query) async {
    try {
      return await LocationService.searchLocation(query);
    } catch (error) {
      _showErrorDialog(
        title: 'Failed to Search Location',
        message: error.toString(),
      );
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      _setLocation(location);
    } catch (error) {
      _showErrorDialog(
        title: 'Failed to Get Current Location',
        message: error.toString(),
      );
    }
  }

  Future<void> _initMap() async {
    try {
      final location = widget.location ??
          await LocationService.getLastKnownLocation() ??
          await LocationService.getLocationByLocale();
      if (location != null) {
        _setLocation(location);
      }
    } catch (error) {
      _showErrorDialog(
        title: 'Failed to Get Initial Location',
        message: error.toString(),
      );
    }
  }

  void _onMapMoved() {
    setState(() {
      _isMapMoved = true;
    });

    _mapMovedTimer?.cancel();
    _mapMovedTimer = Timer(const Duration(milliseconds: 500), () {
      final bounds = _mapController.camera.visibleBounds;
      final center = _mapController.camera.center;
      widget.onBoundsChanged?.call(bounds, center);
    });
  }

  void _onLongPress(LatLng latLng) async {
    try {
      final location = await LocationService.getLocationByCoordinates(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      );
      if (location != null) {
        _setLocation(location);
      }
    } catch (error) {
      _showErrorDialog(
        title: 'Failed to Get Location',
        message: error.toString(),
      );
    }
  }

  void _showLocationDetails() {
    if (_location == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Suggested for better UX
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                spacing: 16.0,
                mainAxisSize: MainAxisSize.min, // Fit content
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [                  
                  Text(
                    _location!.fullName,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _location!.fullName,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMap();
    });
  }

  @override
  void dispose() {
    _mapMovedTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _location?.latLng ?? LatLng(0.0, 0.0),
            initialZoom: 10.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (position, hasGesture) => _onMapMoved(),
            onLongPress: (tapPosition, latLng) => _onLongPress(latLng),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.crowdpass',
            ),
            if (_location != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _location!.latLng,
                    alignment: Alignment.topCenter,
                    height: 48,
                    width: 48,
                    child: GestureDetector(
                      onTap: _showLocationDetails,
                      child: const LocationMapPin(),
                    ),
                  ),
                ],
              ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints.expand(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DebouncedSearchBar<Location>(
                hintText: 'Search location',
                initialValue: _location,
                getDisplayText: (location) => location.fullName,
                tileBuilder: (context, location) {
                  return ListTile(
                    leading: const Icon(Icons.location_pin),
                    title: Text(
                      location.shortName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      location.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
                searchFunction: _searchLocation,
                onResultSelected: _setLocation,
              ),
              const Spacer(),
              if (_location != null && _isMapMoved)
                ...[
                  RoundIconButton(
                    icon: const Icon(Icons.near_me),
                    onPressed: () => _setLocation(_location!),
                  ),
                  const SizedBox(height: 8),
                ],
              if (_location != null)
                ...[
                  RoundIconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _openMapsApp,
                  ),
                  const SizedBox(height: 8),
                ],
              RoundIconButton(
                icon: const Icon(Icons.my_location),
                onPressed: _getCurrentLocation,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LocationMapPin extends StatelessWidget {
  const LocationMapPin({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shadow
        Positioned(
          bottom: 0,
          child: Container(
            width: 40,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.elliptical(20, 5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
        // Icon
        Icon(
          Icons.location_pin,
          size: 50,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}