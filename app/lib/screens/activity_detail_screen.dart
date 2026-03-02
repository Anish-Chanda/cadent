import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/activity.dart';
import '../utils/polyline_decoder.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../widgets/activity_charts.dart';
import '../services/streams_service.dart';


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
  // Streams data loaded from backend (or debug asset)
  List<double>? _elevationSamplesLoaded;
  List<DateTime>? _elevationTimestampsLoaded;
  List<double>? _speedKmhSamplesLoaded;
  List<DateTime>? _speedTimestampsLoaded;
  List<double>? _distanceSamplesLoaded;
  bool _loadingStreams = false;
  String? _streamsError;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    // Start loading streams for charts (use debug asset during development)
    _loadStreams();
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
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusXL),
                    topRight: Radius.circular(AppSpacing.radiusXL),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.2),
                      blurRadius: AppSpacing.xs,
                      offset: const Offset(0, -5),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
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
      styleString: AppTheme.getMapStyle(context),
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
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
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
                      color: Theme.of(context).colorScheme.secondaryContainer,
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
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.activity.activityType == 'road_bike' ? 'Ride' : 'Run',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
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
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.activity.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ) ?? const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(widget.activity.startTime),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.outline,
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
        
        // Graphs (elevation / pace) section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _loadingStreams
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : ActivityCharts(
                  elevationSamples: _elevationSamplesLoaded ?? _mockElevationSamples(),
                  elevationTimestamps: _elevationTimestampsLoaded ?? _mockElevationTimestamps(),
                  distanceSamples: _distanceSamplesLoaded ?? _mockElevationSamples(),
                  paceSamples: _speedKmhSamplesLoaded ?? _mockSpeedKmhSamples(),
                  paceTimestamps: _speedTimestampsLoaded ?? _mockPaceTimestamps(),
                ),
        ),
        if (_streamsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Streams error: ${_streamsError!}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
                value: '${widget.activity.stats!.elevationGainM}',
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
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
              color: Theme.of(context).colorScheme.outline,
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ) ?? const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.outline,
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

  // Graphs are rendered by `ActivityCharts` in place of the old placeholder.


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

  // --- Mock data helpers (for local preview until backend streams are available) ---
  List<double> _mockElevationSamples() {
    // Example elevation stream in meters (small synthetic route)
    return [
      14.2, 14.3, 14.1, 15.0, 16.2, 15.8, 17.0, 18.5, 20.2, 22.0, 24.5, 26.0, 28.0,
      30.1, 32.0, 34.5, 36.0, 35.2, 33.0, 31.0, 29.0, 27.0, 25.0, 22.5, 20.0,
    ];
  }

  List<double> _mockSpeedKmhSamples() {
    // Example speed stream in m/s (converted to km/h for display)
    final speedsMs = [2.9, 3.0, 3.1, 3.2, 3.5, 4.0, 4.2, 4.1, 3.9, 3.7, 3.5, 3.3, 3.1, 2.9];
    return speedsMs.map((s) => s * 3.6).toList();
  }

  List<DateTime> _mockElevationTimestamps() {
    final start = DateTime.parse('2025-11-10T15:30:00Z');
    final samples = _mockElevationSamples();
    return List.generate(samples.length, (i) => start.add(Duration(seconds: i)));
  }

  List<DateTime> _mockPaceTimestamps() {
    final start = DateTime.parse('2025-11-10T15:30:00Z');
    final samples = _mockSpeedKmhSamples();
    return List.generate(samples.length, (i) => start.add(Duration(seconds: i)));
  }

  // Load streams for this activity. During development we default to the
  // debug asset so developers can preview charts without a running backend.
  Future<void> _loadStreams() async {
    setState(() {
      _loadingStreams = true;
      _streamsError = null;
    });

    try {
      final model = await StreamsService.instance.fetchStreamsForActivity(widget.activity.id, useDebugAsset: false);
      if (model == null) {
        setState(() {
          _streamsError = 'No streams returned from service';
        });
        return;
      }

      // Build absolute timestamps from the model's time offsets using the
      // activity's recorded start time. If the model provided absolute
      // datetimes the helper will still produce sensible values.
      final times = model.timeStampsFrom(widget.activity.startTime);
      final distance = model.numericSeries('distance');
      final elev = model.numericSeries('elevation');
      final speedMs = model.numericSeries('speed'); // backend commonly returns m/s

      // Align lengths to the shortest series
      var minLen = times.length;
      if (distance.length < minLen) minLen = distance.length;
      if (elev.length < minLen) minLen = elev.length;
      if (speedMs.length < minLen) minLen = speedMs.length;
      
      final trimmedDistances = distance.take(minLen).toList();
      final trimmedTimes = times.take(minLen).toList();
      final trimmedElev = elev.take(minLen).map((e) => e).toList();
      final trimmedSpeedKmh = speedMs.take(minLen).map((s) => s * 3.6).toList();

      if (!mounted) return;
      setState(() {
        _elevationTimestampsLoaded = trimmedTimes;
        _elevationSamplesLoaded = trimmedElev;
        _distanceSamplesLoaded = trimmedDistances;
        _speedTimestampsLoaded = trimmedTimes;
        _speedKmhSamplesLoaded = trimmedSpeedKmh;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _streamsError = e.toString();
      });
    } finally {
      if (mounted) {
      setState(() {
        _loadingStreams = false;
      });
      }
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