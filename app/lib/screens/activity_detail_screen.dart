import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/activity.dart';
import '../utils/polyline_decoder.dart';
import 'package:intl/intl.dart';


class ActivityDetailScreen extends StatefulWidget {
  final Activity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen>
    with TickerProviderStateMixin {
  MapLibreMapController? _mapController;
  Line? _routeLine;
  DraggableScrollableController? _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
  }

  @override
  void deactivate() {
    // Clean up resources when widget is being deactivated
    _routeLine = null;
    super.deactivate();
  }

  @override
  void dispose() {
    // Just nullify references - let MapLibre handle cleanup when map is destroyed
    _routeLine = null;
    _mapController = null;
    _sheetController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          _buildFullScreenMap(),
          
          // Top app bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildAppBar(),
          ),
          
          // Bottom draggable sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.45, // 45% of screen height
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildBottomSheetContent(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenMap() {
    // Decode polyline points (guaranteed to exist)
    final polylinePoints = _decodePolylinePoints();
    
    // Use middle point of route as center
    final center = polylinePoints.isNotEmpty
        ? polylinePoints[polylinePoints.length ~/ 2]
        : _getBboxCenter();
    
    const zoom = 14.0;

    return MapLibreMap(
      styleString: 'https://tiles.openfreemap.org/styles/liberty',
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: zoom,
      ),
      onMapCreated: (MapLibreMapController controller) async {
        if (!mounted) return;
        
        _mapController = controller;
        debugPrint('Activity detail map controller created');
        
        // Wait for map to initialize
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        
        // Add route line and fit bounds
        _addRouteToMap(polylinePoints);
        
        // Fit to route bounds with better padding
        if (!mounted) return;
        _fitMapToBounds(polylinePoints);
      },
    );
  }

  List<LatLng> _decodePolylinePoints() {
    try {
      final decodedPoints = PolylineDecoder.decode(widget.activity.polyline!);
      return decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    } catch (e) {
      debugPrint('Error decoding polyline: $e');
      return [];
    }
  }

  LatLng _getBboxCenter() {
    final bbox = widget.activity.bbox!;
    return LatLng(
      (bbox.minLat + bbox.maxLat) / 2,
      (bbox.minLon + bbox.maxLon) / 2,
    );
  }

  Widget _buildBottomSheetContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        
        // Activity header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.activity.activityType == 'road_bike' 
                              ? Icons.directions_bike 
                              : Icons.directions_run,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.activity.activityType == 'road_bike' ? 'Ride' : 'Run',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(widget.activity.startTime),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.activity.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(widget.activity.startTime),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Main stats grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildStatsGrid(),
        ),
        
        const SizedBox(height: 24),
        
        // Graphs placeholder
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildGraphsSection(),
        ),
        
        const SizedBox(height: 100), // Bottom padding for sheet
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        // Primary stats row
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                label: 'Distance',
                value: widget.activity.stats!.derived.distanceKm.toStringAsFixed(2),
                unit: 'km',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                label: 'Moving Time',
                value: _formatDuration(widget.activity.stats!.elapsedSeconds),
                unit: '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Secondary stats row
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                label: 'Elevation Gain',
                value: '${widget.activity.stats!.elevationGainM.round()}',
                unit: 'm',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: widget.activity.activityType == 'road_bike'
                  ? _buildStatItem(
                      label: 'Avg Speed',
                      value: widget.activity.stats!.derived.speedKmh!.toStringAsFixed(2),
                      unit: 'km/h',
                    )
                  : _buildStatItem(
                      label: 'Avg Pace',
                      value: widget.activity.formattedPace,
                      unit: '',
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraphsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Graphs Coming Soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Performance analytics and charts will be available here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }


  String _formatDate(DateTime dateTime) {
    final formatter = DateFormat("MMMM d, y 'at' HH:mm");
    return formatter.format(dateTime);
  }
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;

    final twoDigits = NumberFormat('00');

    if (hours > 0) {
      return '$hours:${twoDigits.format(minutes)}:${twoDigits.format(secs)}';
    } else {
      return '$minutes:${twoDigits.format(secs)}';
    }
  }

  void _addRouteToMap(List<LatLng> points) async {
    if (!mounted || _mapController == null || _routeLine != null) {
      debugPrint('Cannot add route: widget disposed, controller not ready, or route already exists');
      return;
    }

    try {
      final lineOptions = LineOptions(
        geometry: points,
        lineColor: '#007AFF',
        lineWidth: 4.0,
        lineOpacity: 0.8,
      );

      _routeLine = await _mapController!.addLine(lineOptions);
      if (mounted) {
        debugPrint('Route line added to map with ${points.length} points');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error adding route line to map: $e');
      }
    }
  }

  void _fitMapToBounds(List<LatLng> points) async {
    if (!mounted || _mapController == null) return;
    
    try {
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;
      
      for (final point in points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      // Add padding around the route
      const routePadding = 0.01;
      minLat -= routePadding;
      maxLat += routePadding;
      minLng -= routePadding;
      maxLng += routePadding;
      
      // Get screen dimensions for responsive padding
      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final screenWidth = mediaQuery.size.width;
      
      // Adjust padding to account for the expanded drawer
      final topPadding = screenHeight * 0.08; // Space for status bar and safe area
      final bottomPadding = screenHeight * 0.55; // Space for expanded drawer
      final sidePadding = screenWidth * 0.05; // Side margins
      
      await _mapController!.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          top: topPadding,
          left: sidePadding,
          bottom: bottomPadding,
          right: sidePadding,
        ),
      );
    } catch (e) {
      debugPrint('Failed to fit map to bounds: $e');
    }
  }
}