import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/nearby_healthcare_place.dart';
import '../theme/pharmalens_theme.dart';

class MapCoordinates {
  const MapCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class UniversalHealthcareMapView extends StatefulWidget {
  const UniversalHealthcareMapView({
    super.key,
    required this.initialCenter,
    this.userLocation,
    required this.places,
    this.selectedPlace,
    required this.onPlaceSelected,
    required this.onMapTap,
    this.initialZoom = 14.5,
    this.controller,
  });

  final MapCoordinates initialCenter;
  final MapCoordinates? userLocation;
  final List<NearbyHealthcarePlace> places;
  final NearbyHealthcarePlace? selectedPlace;
  final ValueChanged<NearbyHealthcarePlace> onPlaceSelected;
  final VoidCallback onMapTap;
  final double initialZoom;
  final UniversalMapController? controller;

  @override
  State<UniversalHealthcareMapView> createState() =>
      UniversalHealthcareMapViewState();
}

class UniversalMapController {
  UniversalHealthcareMapViewState? _state;

  void _attach(UniversalHealthcareMapViewState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void animateTo(double latitude, double longitude, {double? zoom}) {
    _state?.animateTo(latitude, longitude, zoom: zoom);
  }

  void zoomIn() {
    _state?.zoomIn();
  }

  void zoomOut() {
    _state?.zoomOut();
  }
}

class UniversalHealthcareMapViewState extends State<UniversalHealthcareMapView>
    with SingleTickerProviderStateMixin {
  late double _centerLat;
  late double _centerLng;
  late double _zoom;

  AnimationController? _animController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;
  Animation<double>? _zoomAnim;

  Offset? _lastFocalPoint;
  double _scaleStartZoom = 14.0;

  @override
  void initState() {
    super.initState();
    _centerLat = widget.initialCenter.latitude;
    _centerLng = widget.initialCenter.longitude;
    _zoom = widget.initialZoom.clamp(4.0, 18.0);

    widget.controller?._attach(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          if (_latAnim != null) _centerLat = _latAnim!.value;
          if (_lngAnim != null) _centerLng = _lngAnim!.value;
          if (_zoomAnim != null) _zoom = _zoomAnim!.value;
        });
      });
  }

  @override
  void didUpdateWidget(UniversalHealthcareMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animController?.dispose();
    super.dispose();
  }

  void animateTo(double lat, double lng, {double? zoom}) {
    _animController?.stop();

    final targetZoom = (zoom ?? _zoom).clamp(4.0, 18.0);

    _latAnim = Tween<double>(
      begin: _centerLat,
      end: lat,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
    ));

    _lngAnim = Tween<double>(
      begin: _centerLng,
      end: lng,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
    ));

    _zoomAnim = Tween<double>(
      begin: _zoom,
      end: targetZoom,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
    ));

    _animController?.forward(from: 0);
  }

  void zoomIn() {
    animateTo(_centerLat, _centerLng, zoom: (_zoom + 1.0).clamp(4.0, 18.0));
  }

  void zoomOut() {
    animateTo(_centerLat, _centerLng, zoom: (_zoom - 1.0).clamp(4.0, 18.0));
  }

  // Web Mercator Math
  static double _lngToX(double lng, int z) {
    return 256.0 * math.pow(2, z) * (lng + 180.0) / 360.0;
  }

  static double _latToY(double lat, int z) {
    final latRad = lat * math.pi / 180.0;
    final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    final yNorm = 0.5 - (math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi));
    return 256.0 * math.pow(2, z) * yNorm;
  }

  static double _xToLng(double x, int z) {
    final xNorm = x / (256.0 * math.pow(2, z));
    return xNorm * 360.0 - 180.0;
  }

  static double _yToLat(double y, int z) {
    final yNorm = y / (256.0 * math.pow(2, z));
    final n = math.pi - 2.0 * math.pi * yNorm;
    final sinhN = (math.exp(n) - math.exp(-n)) / 2.0;
    return math.atan(sinhN) * 180.0 / math.pi;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _animController?.stop();
    _lastFocalPoint = details.localFocalPoint;
    _scaleStartZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    if (_lastFocalPoint == null) return;

    final zInt = _zoom.floor().clamp(1, 18);
    final scale = math.pow(2, _zoom - zInt).toDouble();

    final delta = details.localFocalPoint - _lastFocalPoint!;
    _lastFocalPoint = details.localFocalPoint;

    // Pan in world coordinates
    final curX = _lngToX(_centerLng, zInt);
    final curY = _latToY(_centerLat, zInt);

    final newX = curX - (delta.dx / scale);
    final newY = curY - (delta.dy / scale);

    final newLng = _xToLng(newX, zInt);
    final newLat = _yToLat(newY, zInt).clamp(-85.0, 85.0);

    // Zoom
    double newZoom = _zoom;
    if (details.scale != 1.0) {
      newZoom = (_scaleStartZoom + (math.log(details.scale) / math.ln2))
          .clamp(4.0, 18.0);
    }

    setState(() {
      _centerLat = newLat;
      _centerLng = newLng;
      _zoom = newZoom;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PharmaLensTheme.isDark(context);
    final palette = PharmaLensTheme.paletteOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final size = Size(width, height);

        final zInt = _zoom.floor().clamp(1, 18);
        final scale = math.pow(2, _zoom - zInt).toDouble();

        final centerX = _lngToX(_centerLng, zInt);
        final centerY = _latToY(_centerLat, zInt);

        // Calculate tile range to cover the viewport
        final halfW = (width / 2.0) / scale;
        final halfH = (height / 2.0) / scale;

        final minX = centerX - halfW;
        final maxX = centerX + halfW;
        final minY = centerY - halfH;
        final maxY = centerY + halfH;

        final minTileX = (minX / 256.0).floor();
        final maxTileX = (maxX / 256.0).floor();
        final minTileY = (minY / 256.0).floor();
        final maxTileY = (maxY / 256.0).floor();

        final maxTiles = 1 << zInt;
        final subdomains = const ['a', 'b', 'c', 'd'];

        final tileWidgets = <Widget>[];

        for (var tx = minTileX; tx <= maxTileX; tx++) {
          final wrappedTx = ((tx % maxTiles) + maxTiles) % maxTiles;

          for (var ty = minTileY; ty <= maxTileY; ty++) {
            if (ty < 0 || ty >= maxTiles) continue;

            final tileScreenX = (width / 2.0) + ((tx * 256.0 - centerX) * scale);
            final tileScreenY = (height / 2.0) + ((ty * 256.0 - centerY) * scale);
            final tileSize = (256.0 * scale).ceilToDouble() + 1.0;

            final sub = subdomains[((wrappedTx + ty) % 4).abs()];
            final tileUrl = isDark
                ? 'https://$sub.basemaps.cartocdn.com/rastertiles/dark_all/$zInt/$wrappedTx/$ty.png'
                : 'https://$sub.basemaps.cartocdn.com/rastertiles/voyager/$zInt/$wrappedTx/$ty.png';

            final osmFallbackUrl =
                'https://tile.openstreetmap.org/$zInt/$wrappedTx/$ty.png';

            tileWidgets.add(
              Positioned(
                left: tileScreenX,
                top: tileScreenY,
                width: tileSize,
                height: tileSize,
                child: Image.network(
                  tileUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) {
                    return Image.network(
                      osmFallbackUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return Container(
                          color: isDark
                              ? const Color(0xFF0F1E28)
                              : const Color(0xFFE8F1F5),
                          child: Center(
                            child: Icon(
                              Icons.grid_4x4_rounded,
                              size: 14,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            );
          }
        }

        // Marker widgets
        final markerWidgets = <Widget>[];

        for (final place in widget.places) {
          final isSelected = widget.selectedPlace?.id == place.id;
          final pX = _lngToX(place.longitude, zInt);
          final pY = _latToY(place.latitude, zInt);

          final screenX = (width / 2.0) + ((pX - centerX) * scale);
          final screenY = (height / 2.0) + ((pY - centerY) * scale);

          // Hide markers off screen
          if (screenX < -120 ||
              screenX > width + 120 ||
              screenY < -120 ||
              screenY > height + 120) {
            continue;
          }

          markerWidgets.add(
            Positioned(
              left: screenX,
              top: screenY,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -1.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onPlaceSelected(place);
                  },
                  child: _MapPin(
                    place: place,
                    selected: isSelected,
                  ),
                ),
              ),
            ),
          );
        }

        // User GPS position pin
        Widget? userLocationWidget;
        if (widget.userLocation != null) {
          final uX = _lngToX(widget.userLocation!.longitude, zInt);
          final uY = _latToY(widget.userLocation!.latitude, zInt);

          final uScreenX = (width / 2.0) + ((uX - centerX) * scale);
          final uScreenY = (height / 2.0) + ((uY - centerY) * scale);

          userLocationWidget = Positioned(
            left: uScreenX,
            top: uScreenY,
            child: const FractionalTranslation(
              translation: Offset(-0.5, -0.5),
              child: _UserLocationDot(),
            ),
          );
        }

        return Container(
          color: isDark ? const Color(0xFF071D28) : const Color(0xFFE8F1F5),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: (details) => _onScaleUpdate(details, size),
            onScaleEnd: _onScaleEnd,
            onTap: widget.onMapTap,
            onDoubleTap: zoomIn,
            child: ClipRect(
              child: Stack(
                children: [
                  // Base tile grid
                  ...tileWidgets,

                  // User location pulse
                  if (userLocationWidget != null) userLocationWidget,

                  // Pharmacy markers
                  ...markerWidgets,

                  // Watermark / Attribution
                  Positioned(
                    bottom: 270,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white)
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '© OpenStreetMap, © CARTO',
                        style: TextStyle(
                          fontSize: 9,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.place,
    required this.selected,
  });

  final NearbyHealthcarePlace place;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pinColor =
        selected ? const Color(0xFFFF6F59) : PharmaLensColors.teal;
    final size = selected ? 48.0 : 38.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: 0.45),
                blurRadius: selected ? 12 : 6,
                spreadRadius: selected ? 3 : 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            place.isPharmacy ? Icons.local_pharmacy_rounded : Icons.local_hospital_rounded,
            color: Colors.white,
            size: selected ? 24 : 19,
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: pinColor),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _UserLocationDot extends StatefulWidget {
  const _UserLocationDot();

  @override
  State<_UserLocationDot> createState() => _UserLocationDotState();
}

class _UserLocationDotState extends State<_UserLocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28.0 + (pulse * 18.0),
              height: 28.0 + (pulse * 18.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PharmaLensColors.info.withValues(alpha: (1.0 - pulse) * 0.4),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: PharmaLensColors.info,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
