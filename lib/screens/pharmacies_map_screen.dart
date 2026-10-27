import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_healthcare_place.dart';
import '../services/nearby_healthcare_service.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/universal_map_view.dart';

class PharmaciesMapScreen extends StatefulWidget {
  const PharmaciesMapScreen({
    super.key,
  });

  @override
  State<PharmaciesMapScreen> createState() {
    return _PharmaciesMapScreenState();
  }
}

class _PharmaciesMapScreenState extends State<PharmaciesMapScreen> {
  static const double _searchRadiusMeters = 5000;

  static const int _maximumPlaces = 8;

  static const LatLng _beirutFallback =
  LatLng(
    33.8938,
    35.5018,
  );

  static const String _mapStyleLight = '''
[
  {
    "featureType": "poi",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  }
]
''';

  static const String _mapStyleDark = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#071D28"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#B7CED8"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#061B27"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{"color": "#1B4C60"}]
  },
  {
    "featureType": "poi",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#12384A"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#082230"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9CB4BE"}]
  },
  {
    "featureType": "transit",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#05202D"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#7FA0AE"}]
  }
]
''';

  final NearbyHealthcareService _service =
  NearbyHealthcareService();

  GoogleMapController? _mapController;
  final UniversalMapController _universalMapController = UniversalMapController();

  Position? _userPosition;

  NearbyHealthcarePlace? _selectedPlace;

  List<NearbyHealthcarePlace> _places =
  const <NearbyHealthcarePlace>[];

  Set<Marker> _markers =
  const <Marker>{};

  bool _isLoading = true;

  bool _isRefreshing = false;

  String _errorMessage = '';

  int _requestSerial = 0;

  bool _started = false;

  String _lastLanguageCode = '';

  bool get _isArabic {
    return Localizations.localeOf(
      context,
    ).languageCode.toLowerCase() ==
        'ar';
  }

  String get _languageCode {
    return _isArabic
        ? 'ar'
        : 'en';
  }

  String _text({
    required String en,
    required String ar,
  }) {
    return _isArabic
        ? ar
        : en;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextLanguage =
    Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();

    if (!_started) {
      _started = true;

      _lastLanguageCode =
          nextLanguage;

      WidgetsBinding.instance
          .addPostFrameCallback(
            (_) {
          if (mounted) {
            _loadNearby();
          }
        },
      );

      return;
    }

    if (_lastLanguageCode !=
        nextLanguage) {
      _lastLanguageCode =
          nextLanguage;

      WidgetsBinding.instance
          .addPostFrameCallback(
            (_) {
          if (mounted) {
            _loadNearby();
          }
        },
      );
    }
  }

  Future<void> _loadNearby({
    bool forceRefresh = false,
  }) async {
    final requestId =
    ++_requestSerial;

    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = '';

      _selectedPlace =
      null;

      if (forceRefresh) {
        _isRefreshing =
        true;
      } else {
        _isLoading =
        true;
      }
    });

    try {
      final position =
      await _resolveCurrentPosition();

      if (!_isCurrentRequest(
        requestId,
      )) {
        return;
      }

      final results =
      await _service.loadNearby(
        latitude:
        position.latitude,
        longitude:
        position.longitude,
        languageCode:
        _languageCode,
        radiusMeters:
        _searchRadiusMeters,
        maxResults:
        _maximumPlaces,
        forceRefresh:
        forceRefresh,
      );

      if (!_isCurrentRequest(
        requestId,
      )) {
        return;
      }

      final sorted =
      List<NearbyHealthcarePlace>.from(
        results,
      )
        ..sort(
              (
              first,
              second,
              ) {
            return _distanceTo(
              first,
              position,
            ).compareTo(
              _distanceTo(
                second,
                position,
              ),
            );
          },
        );

      final nearest =
      sorted
          .take(
        _maximumPlaces,
      )
          .toList(
        growable:
        false,
      );

      setState(() {
        _userPosition =
            position;

        _places =
        List<NearbyHealthcarePlace>.unmodifiable(
          nearest,
        );

        _markers =
            _buildMarkers(
              nearest,
            );

        _isLoading =
        false;

        _isRefreshing =
        false;

        if (nearest.isEmpty) {
          _errorMessage =
              _text(
                en:
                'No pharmacies were found within 5 km.',
                ar:
                'لم يتم العثور على صيدليات ضمن 5 كم.',
              );
        }
      });

      await _moveToUser();
    } on _LocationAccessException catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Location could not be resolved.',
        error,
        stackTrace,
      );

      if (!_isCurrentRequest(
        requestId,
      )) {
        return;
      }

      setState(() {
        _isLoading =
        false;

        _isRefreshing =
        false;

        _errorMessage =
            error.message;
      });
    } on NearbyHealthcareException catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Nearby healthcare search failed.',
        error,
        stackTrace,
      );

      if (!_isCurrentRequest(
        requestId,
      )) {
        return;
      }

      setState(() {
        _isLoading =
        false;

        _isRefreshing =
        false;

        /*
         * NearbyHealthcareException.message is UI-safe.
         */
        _errorMessage =
            error.message;
      });
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Unexpected healthcare map failure.',
        error,
        stackTrace,
      );

      if (!_isCurrentRequest(
        requestId,
      )) {
        return;
      }

      setState(() {
        _isLoading =
        false;

        _isRefreshing =
        false;

        _errorMessage =
            _text(
              en:
              'Nearby healthcare search is temporarily unavailable. Please try again.',
              ar:
              'البحث عن خدمات الرعاية الصحية القريبة غير متاح مؤقتًا. يرجى إعادة المحاولة.',
            );
      });
    }
  }

  bool _isCurrentRequest(
      int requestId,
      ) {
    return mounted &&
        requestId ==
            _requestSerial;
  }

  Future<Position> _resolveCurrentPosition() async {
    bool serviceEnabled;

    try {
      serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not check location service.',
        error,
        stackTrace,
      );

      throw _LocationAccessException(
        _text(
          en:
          'Your location could not be accessed.',
          ar:
          'تعذر الوصول إلى موقعك.',
        ),
      );
    }

    if (!serviceEnabled) {
      if (mounted) {
        await _showLocationDisabledDialog();
      }

      throw _LocationAccessException(
        _text(
          en:
          'Location services are disabled. Enable GPS to find nearby healthcare services.',
          ar:
          'خدمات الموقع متوقفة. فعّل GPS للعثور على خدمات الرعاية الصحية القريبة.',
        ),
      );
    }

    LocationPermission permission;

    try {
      permission =
      await Geolocator
          .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator
            .requestPermission();
      }
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not request location permission.',
        error,
        stackTrace,
      );

      throw _LocationAccessException(
        _text(
          en:
          'Location permission could not be checked.',
          ar:
          'تعذر التحقق من صلاحية الموقع.',
        ),
      );
    }

    if (permission ==
        LocationPermission.denied) {
      throw _LocationAccessException(
        _text(
          en:
          'Location permission is required to find nearby pharmacies and medical centers.',
          ar:
          'صلاحية الموقع مطلوبة للعثور على الصيدليات والمراكز الطبية القريبة.',
        ),
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      if (mounted) {
        await _showPermissionBlockedDialog();
      }

      throw _LocationAccessException(
        _text(
          en:
          'Location permission is blocked. Enable it from app settings.',
          ar:
          'صلاحية الموقع محظورة. فعّلها من إعدادات التطبيق.',
        ),
      );
    }

    Position? lastKnown;

    try {
      lastKnown =
      await Geolocator
          .getLastKnownPosition();
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not read last known location.',
        error,
        stackTrace,
      );
    }

    try {
      return await Geolocator
          .getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.medium,
          timeLimit:
          Duration(
            seconds: 12,
          ),
        ),
      );
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Current location request failed.',
        error,
        stackTrace,
      );

      if (lastKnown != null) {
        return lastKnown;
      }

      throw _LocationAccessException(
        _text(
          en:
          'Your current location could not be determined. Check GPS and try again.',
          ar:
          'تعذر تحديد موقعك الحالي. تحقق من GPS وحاول مرة أخرى.',
        ),
      );
    }
  }

  Set<Marker> _buildMarkers(
      List<NearbyHealthcarePlace> places,
      ) {
    return places.map(
          (
          place,
          ) {
        final selected =
            _selectedPlace?.id ==
                place.id;

        final hue =
        selected
            ? BitmapDescriptor
            .hueOrange
            : place
            .isPharmacy
            ? BitmapDescriptor
            .hueAzure
            : BitmapDescriptor
            .hueViolet;

        return Marker(
          markerId:
          MarkerId(
            place.id,
          ),
          position:
          LatLng(
            place.latitude,
            place.longitude,
          ),
          icon:
          BitmapDescriptor
              .defaultMarkerWithHue(
            hue,
          ),
          infoWindow:
          InfoWindow(
            title:
            place.name,
            snippet:
            '${_kindLabel(place)} • ${_distanceLabel(place)}',
          ),
          onTap: () {
            _selectPlace(
              place,
            );
          },
        );
      },
    ).toSet();
  }

  void _selectPlace(
      NearbyHealthcarePlace place,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPlace =
          place;

      _markers =
          _buildMarkers(
            _places,
          );
    });

    _universalMapController.animateTo(
      place.latitude,
      place.longitude,
      zoom: 16,
    );

    _mapController
        ?.animateCamera(
      CameraUpdate
          .newLatLngZoom(
        LatLng(
          place.latitude,
          place.longitude,
        ),
        16,
      ),
    );
  }

  void _clearSelectedPlace() {
    if (_selectedPlace ==
        null) {
      return;
    }

    setState(() {
      _selectedPlace =
      null;

      _markers =
          _buildMarkers(
            _places,
          );
    });
  }

  Future<void> _moveToUser() async {
    final position =
        _userPosition;

    if (position == null) {
      return;
    }

    _universalMapController.animateTo(
      position.latitude,
      position.longitude,
      zoom: 14.5,
    );

    final controller =
        _mapController;

    if (controller == null) {
      return;
    }

    try {
      await controller
          .animateCamera(
        CameraUpdate
            .newLatLngZoom(
          LatLng(
            position.latitude,
            position.longitude,
          ),
          14.5,
        ),
      );
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Map recenter failed.',
        error,
        stackTrace,
      );
    }
  }

  double _distanceTo(
      NearbyHealthcarePlace place,
      Position position,
      ) {
    return Geolocator
        .distanceBetween(
      position.latitude,
      position.longitude,
      place.latitude,
      place.longitude,
    );
  }

  String _distanceLabel(
      NearbyHealthcarePlace place,
      ) {
    final position =
        _userPosition;

    if (position == null) {
      return _text(
        en:
        'Nearby',
        ar:
        'قريب',
      );
    }

    final meters =
    _distanceTo(
      place,
      position,
    );

    if (meters <
        1000) {
      return _isArabic
          ? '${meters.round()} م'
          : '${meters.round()} m';
    }

    final kilometers =
        meters /
            1000;

    return _isArabic
        ? '${kilometers.toStringAsFixed(1)} كم'
        : '${kilometers.toStringAsFixed(1)} km';
  }

  String _kindLabel(
      NearbyHealthcarePlace place,
      ) {
    if (place.isPharmacy) {
      return _text(
        en:
        'Pharmacy',
        ar:
        'صيدلية',
      );
    }

    return _text(
      en:
      'Medical center',
      ar:
      'مركز طبي',
    );
  }

  String _openingLabel(
      NearbyHealthcarePlace place,
      ) {
    switch (place.openNow) {
      case true:
        return _text(
          en:
          'Open now',
          ar:
          'مفتوح الآن',
        );

      case false:
        return _text(
          en:
          'Closed now',
          ar:
          'مغلق الآن',
        );

      case null:
        return '';
    }
  }

  Future<void> _openDirections(
      NearbyHealthcarePlace place,
      ) async {
    final query =
    <String, String>{
      'api':
      '1',
      'destination':
      '${place.latitude},${place.longitude}',
      'travelmode':
      'driving',
    };

    if (place.placeId
        .trim()
        .isNotEmpty) {
      query[
      'destination_place_id'
      ] = place.placeId.trim();
    }

    final uri =
    Uri.https(
      'www.google.com',
      '/maps/dir/',
      query,
    );

    await _launchExternalUri(
      uri,
      failureMessage:
      _text(
        en:
        'Could not open directions.',
        ar:
        'تعذر فتح الطريق.',
      ),
    );
  }

  Future<void> _callPlace(
      NearbyHealthcarePlace place,
      ) async {
    final phone =
    place.phone.trim();

    if (phone.isEmpty) {
      _showMessage(
        _text(
          en:
          'No phone number is available for this location.',
          ar:
          'لا يوجد رقم هاتف متاح لهذا المكان.',
        ),
      );

      return;
    }

    await _launchExternalUri(
      Uri(
        scheme:
        'tel',
        path:
        phone,
      ),
      failureMessage:
      _text(
        en:
        'Could not open the phone application.',
        ar:
        'تعذر فتح تطبيق الهاتف.',
      ),
    );
  }

  Future<void> _launchExternalUri(
      Uri uri, {
        required String failureMessage,
      }) async {
    try {
      final opened =
      await launchUrl(
        uri,
        mode:
        LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(
          failureMessage,
        );
      }
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'External URI launch failed.',
        error,
        stackTrace,
      );

      _showMessage(
        failureMessage,
      );
    }
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(
            message,
          ),
        ),
      );
  }

  Future<void> _showLocationDisabledDialog() {
    return showDialog<void>(
      context:
      context,
      builder:
          (
          dialogContext,
          ) {
        final palette =
        PharmaLensTheme.paletteOf(
          dialogContext,
        );

        return AlertDialog(
          backgroundColor:
          palette.surface,
          surfaceTintColor:
          Colors.transparent,
          title:
          Text(
            _text(
              en:
              'Enable location',
              ar:
              'تفعيل الموقع',
            ),
            style:
            TextStyle(
              color:
              palette.textPrimary,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          content:
          Text(
            _text(
              en:
              'Enable GPS to find the closest pharmacies and medical centers.',
              ar:
              'فعّل GPS للعثور على أقرب الصيدليات والمراكز الطبية.',
            ),
            style:
            TextStyle(
              color:
              palette.textSecondary,
              height:
              1.45,
              fontWeight:
              FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
              Text(
                _text(
                  en:
                  'Cancel',
                  ar:
                  'إلغاء',
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(
                  dialogContext,
                ).pop();

                try {
                  await Geolocator
                      .openLocationSettings();
                } catch (
                error,
                stackTrace
                ) {
                  _debugLog(
                    'Could not open location settings.',
                    error,
                    stackTrace,
                  );
                }
              },
              child:
              Text(
                _text(
                  en:
                  'Open settings',
                  ar:
                  'فتح الإعدادات',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionBlockedDialog() {
    return showDialog<void>(
      context:
      context,
      builder:
          (
          dialogContext,
          ) {
        final palette =
        PharmaLensTheme.paletteOf(
          dialogContext,
        );

        return AlertDialog(
          backgroundColor:
          palette.surface,
          surfaceTintColor:
          Colors.transparent,
          title:
          Text(
            _text(
              en:
              'Location permission',
              ar:
              'صلاحية الموقع',
            ),
            style:
            TextStyle(
              color:
              palette.textPrimary,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          content:
          Text(
            _text(
              en:
              'Location permission is blocked. Enable it from app settings.',
              ar:
              'صلاحية الموقع محظورة. فعّلها من إعدادات التطبيق.',
            ),
            style:
            TextStyle(
              color:
              palette.textSecondary,
              height:
              1.45,
              fontWeight:
              FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
              Text(
                _text(
                  en:
                  'Cancel',
                  ar:
                  'إلغاء',
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(
                  dialogContext,
                ).pop();

                try {
                  await Geolocator
                      .openAppSettings();
                } catch (
                error,
                stackTrace
                ) {
                  _debugLog(
                    'Could not open application settings.',
                    error,
                    stackTrace,
                  );
                }
              },
              child:
              Text(
                _text(
                  en:
                  'Open settings',
                  ar:
                  'فتح الإعدادات',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return SafeArea(
      child: Align(
        alignment:
        AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 720,
          ),
          child: Padding(
        padding:
        const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          0,
        ),
        child: Row(
          children: [
            if (Navigator.of(
              context,
            ).canPop())
            Material(
              color:
              palette.surface,
              borderRadius:
              BorderRadius.circular(
                15,
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(
                    context,
                  ).pop();
                },
                borderRadius:
                BorderRadius.circular(
                  15,
                ),
                child: Container(
                  width:
                  46,
                  height:
                  46,
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    border:
                    Border.all(
                      color:
                      palette.border,
                    ),
                    boxShadow:
                    palette.cardShadow,
                  ),
                  child:
                  Icon(
                    Icons.arrow_back_rounded,
                    color:
                    palette.textPrimary,
                  ),
                ),
              ),
            ),

            if (Navigator.of(
              context,
            ).canPop())
            const SizedBox(
              width:
              10,
            ),

            Expanded(
              child: Container(
                height:
                50,
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  14,
                ),
                decoration:
                BoxDecoration(
                  color:
                  palette.surface,
                  borderRadius:
                  BorderRadius.circular(
                    17,
                  ),
                  border:
                  Border.all(
                    color:
                    palette.border,
                  ),
                  boxShadow:
                  isDark
                      ? const <BoxShadow>[]
                      : palette.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .health_and_safety_outlined,
                      color:
                      PharmaLensColors.teal,
                    ),

                    const SizedBox(
                      width:
                      9,
                    ),

                    Expanded(
                      child: Text(
                        _text(
                          en:
                          'Nearby healthcare',
                          ar:
                          'الرعاية الصحية القريبة',
                        ),
                        maxLines:
                        1,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        TextStyle(
                          color:
                          palette.textPrimary,
                          fontSize:
                          15.5,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildMapButtons() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return PositionedDirectional(
      top:
      105,
      end:
      13,
      child: Column(
        children: [
          _MapButton(
            heroTag:
            'healthcare_recenter',
            icon:
            Icons.my_location_rounded,
            foreground:
            PharmaLensColors.info,
            background:
            palette.surface,
            onPressed:
            _userPosition ==
                null
                ? null
                : _moveToUser,
          ),

          const SizedBox(
            height:
            9,
          ),

          _MapButton(
            heroTag:
            'healthcare_zoom_in',
            icon:
            Icons.add_rounded,
            foreground:
            palette.textPrimary,
            background:
            palette.surface,
            onPressed: () {
              _universalMapController.zoomIn();
              _mapController?.animateCamera(CameraUpdate.zoomIn());
            },
          ),

          const SizedBox(
            height:
            9,
          ),

          _MapButton(
            heroTag:
            'healthcare_zoom_out',
            icon:
            Icons.remove_rounded,
            foreground:
            palette.textPrimary,
            background:
            palette.surface,
            onPressed: () {
              _universalMapController.zoomOut();
              _mapController?.animateCamera(CameraUpdate.zoomOut());
            },
          ),

          const SizedBox(
            height:
            9,
          ),

          _MapButton(
            heroTag:
            'healthcare_refresh',
            icon:
            Icons.refresh_rounded,
            foreground:
            PharmaLensColors.teal,
            background:
            palette.surface,
            loading:
            _isRefreshing,
            onPressed:
            _isRefreshing ||
                _isLoading
                ? null
                : () {
              _service
                  .clearCache();

              _loadNearby(
                forceRefresh:
                true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final selected =
        _selectedPlace;

    if (selected != null) {
      return _SelectedPlaceCard(
        place:
        selected,
        kindLabel:
        _kindLabel(
          selected,
        ),
        distanceLabel:
        _distanceLabel(
          selected,
        ),
        openingLabel:
        _openingLabel(
          selected,
        ),
        directionsLabel:
        _text(
          en:
          'Directions',
          ar:
          'الطريق',
        ),
        callLabel:
        _text(
          en:
          'Call',
          ar:
          'اتصال',
        ),
        sourceLabel:
        _text(
          en:
          'Google listing',
          ar:
          'بيانات من Google',
        ),
        onDirections: () {
          _openDirections(
            selected,
          );
        },
        onCall:
        selected.phone
            .trim()
            .isEmpty
            ? null
            : () {
          _callPlace(
            selected,
          );
        },
        onClose:
        _clearSelectedPlace,
      );
    }

    return _NearbyPlacesPanel(
      places:
      _places,
      isArabic:
      _isArabic,
      kindLabel:
      _kindLabel,
      distanceLabel:
      _distanceLabel,
      onSelected:
      _selectPlace,
    );
  }

  Widget _buildErrorBanner() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Material(
      color:
      Colors.transparent,
      child: Container(
        padding:
        const EdgeInsets.all(
          13,
        ),
        decoration:
        BoxDecoration(
          color:
          palette.dangerSurface,
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          border:
          Border.all(
            color:
            PharmaLensColors
                .danger
                .withValues(
              alpha:
              isDark
                  ? 0.46
                  : 0.28,
            ),
          ),
          boxShadow:
          palette.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width:
              38,
              height:
              38,
              decoration:
              BoxDecoration(
                color:
                PharmaLensColors
                    .danger
                    .withValues(
                  alpha:
                  0.10,
                ),
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child:
              const Icon(
                Icons
                    .error_outline_rounded,
                color:
                PharmaLensColors.danger,
                size:
                20,
              ),
            ),

            const SizedBox(
              width:
              9,
            ),

            Expanded(
              child: Text(
                _errorMessage,
                maxLines:
                3,
                overflow:
                TextOverflow.ellipsis,
                style:
                TextStyle(
                  color:
                  palette.textSecondary,
                  height:
                  1.4,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(
              width:
              7,
            ),

            IconButton(
              tooltip:
              _text(
                en:
                'Retry',
                ar:
                'إعادة المحاولة',
              ),
              onPressed:
              _isLoading ||
                  _isRefreshing
                  ? null
                  : () {
                _loadNearby(
                  forceRefresh:
                  true,
                );
              },
              icon:
              const Icon(
                Icons
                    .refresh_rounded,
                color:
                PharmaLensColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Positioned.fill(
      child: Container(
        color:
        Colors.black.withValues(
          alpha:
          isDark
              ? 0.30
              : 0.08,
        ),
        child: Center(
          child: Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              22,
              vertical:
              18,
            ),
            decoration:
            BoxDecoration(
              color:
              palette.surface,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
              border:
              Border.all(
                color:
                palette.border,
              ),
              boxShadow:
              palette.cardShadow,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const SizedBox(
                  width:
                  32,
                  height:
                  32,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2.7,
                  ),
                ),

                const SizedBox(
                  height:
                  12,
                ),

                Text(
                  _text(
                    en:
                    'Finding nearby healthcare...',
                    ar:
                    'جارٍ البحث عن خدمات الرعاية الصحية القريبة...',
                  ),
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    color:
                    palette.textSecondary,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  @override
  void dispose() {
    _requestSerial++;

    _mapController?.dispose();

    _service.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    final userPosition =
        _userPosition;

    final target =
    userPosition == null
        ? _beirutFallback
        : LatLng(
      userPosition.latitude,
      userPosition.longitude,
    );

    final isUniversal = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    final initialCenter = MapCoordinates(
      target.latitude,
      target.longitude,
    );

    final userCoords = userPosition == null
        ? null
        : MapCoordinates(
            userPosition.latitude,
            userPosition.longitude,
          );

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: const FloatingChatbotButton(),
      body: Stack(
        children: [
          if (isUniversal)
            RepaintBoundary(
              child: UniversalHealthcareMapView(
                controller: _universalMapController,
                initialCenter: initialCenter,
                userLocation: userCoords,
                places: _places,
                selectedPlace: _selectedPlace,
                initialZoom: userPosition == null ? 10.5 : 14.5,
                onPlaceSelected: _selectPlace,
                onMapTap: _clearSelectedPlace,
              ),
            )
          else
            RepaintBoundary(
              child: GoogleMap(
                initialCameraPosition:
                CameraPosition(
                  target:
                  target,
                  zoom:
                  userPosition ==
                      null
                      ? 10
                      : 14.5,
                ),
                style:
                isDark
                    ? _mapStyleDark
                    : _mapStyleLight,
                markers:
                _markers,
                myLocationEnabled:
                userPosition !=
                    null,
                myLocationButtonEnabled:
                false,
                mapType:
                MapType.normal,
                compassEnabled:
                false,
                mapToolbarEnabled:
                false,
                zoomControlsEnabled:
                false,
                trafficEnabled:
                false,
                buildingsEnabled:
                false,
                indoorViewEnabled:
                false,
                tiltGesturesEnabled:
                false,
                padding:
                const EdgeInsets.only(
                  top:
                  100,
                  bottom:
                  275,
                ),
                onMapCreated:
                    (
                    controller,
                    ) {
                  _mapController =
                      controller;

                  _moveToUser();
                },
                onTap: (
                    _,
                    ) {
                  _clearSelectedPlace();
                },
              ),
            ),

          _buildHeader(),

          _buildMapButtons(),

          // On wide windows the place list floats as a card beside the map
          // instead of stretching across the whole width.
          if (MediaQuery.sizeOf(context).width >= 900)
            PositionedDirectional(
              start:
              16,
              bottom:
              18,
              width:
              440,
              child:
              _buildBottomPanel(),
            )
          else
            PositionedDirectional(
              start:
              12,
              end:
              12,
              bottom:
              18,
              child:
              _buildBottomPanel(),
            ),

          if (_isLoading)
            _buildLoadingOverlay(),

          if (_errorMessage
              .isNotEmpty &&
              !_isLoading)
            PositionedDirectional(
              top:
              105,
              start:
              16,
              end:
              70,
              child:
              _buildErrorBanner(),
            ),
        ],
      ),
    );
  }

  void _debugLog(
      String message,
      Object error,
      StackTrace stackTrace,
      ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '$message\n$error',
    );

    debugPrintStack(
      stackTrace:
      stackTrace,
    );
  }
}

class _NearbyPlacesPanel
    extends StatelessWidget {
  const _NearbyPlacesPanel({
    required this.places,
    required this.isArabic,
    required this.kindLabel,
    required this.distanceLabel,
    required this.onSelected,
  });

  final List<NearbyHealthcarePlace> places;

  final bool isArabic;

  final String Function(
      NearbyHealthcarePlace place,
      ) kindLabel;

  final String Function(
      NearbyHealthcarePlace place,
      ) distanceLabel;

  final ValueChanged<NearbyHealthcarePlace>
  onSelected;

  String _text({
    required String en,
    required String ar,
  }) {
    return isArabic
        ? ar
        : en;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      constraints:
      const BoxConstraints(
        maxHeight:
        275,
      ),
      padding:
      const EdgeInsets.fromLTRB(
        14,
        13,
        14,
        10,
      ),
      decoration:
      PharmaLensDecorations
          .surfaceCard(
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        isDark:
        isDark,
      ),
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .near_me_rounded,
                color:
                PharmaLensColors.info,
              ),

              const SizedBox(
                width:
                8,
              ),

              Expanded(
                child: Text(
                  _text(
                    en:
                    'Closest to you',
                    ar:
                    'الأقرب إليك',
                  ),
                  style:
                  TextStyle(
                    color:
                    palette.textPrimary,
                    fontSize:
                    17,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  9,
                  vertical:
                  5,
                ),
                decoration:
                BoxDecoration(
                  color:
                  palette.tealSurface,
                  borderRadius:
                  BorderRadius.circular(
                    999,
                  ),
                ),
                child: Text(
                  '${places.length}',
                  style:
                  const TextStyle(
                    color:
                    PharmaLensColors.teal,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            6,
          ),

          if (places.isEmpty)
            Padding(
              padding:
              const EdgeInsets.symmetric(
                vertical:
                20,
              ),
              child: Center(
                child: Text(
                  _text(
                    en:
                    'No nearby results yet.',
                    ar:
                    'لا توجد نتائج قريبة بعد.',
                  ),
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    color:
                    palette.textSecondary,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap:
                true,
                padding:
                EdgeInsets.zero,
                itemCount:
                places.length >
                    4
                    ? 4
                    : places.length,
                separatorBuilder:
                    (
                    context,
                    index,
                    ) {
                  return Divider(
                    height:
                    1,
                    color:
                    palette.borderSoft,
                  );
                },
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final place =
                  places[
                  index
                  ];

                  return ListTile(
                    dense:
                    true,
                    contentPadding:
                    EdgeInsets.zero,
                    leading:
                    _PlaceAvatar(
                      isPharmacy:
                      place.isPharmacy,
                    ),
                    title:
                    Text(
                      place.name,
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      TextStyle(
                        color:
                        palette.textPrimary,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    subtitle:
                    Text(
                      '${kindLabel(place)} • ${distanceLabel(place)}',
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      TextStyle(
                        color:
                        palette.textSecondary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    trailing:
                    Icon(
                      Icons.chevron_right_rounded,
                      color:
                      palette.textMuted,
                    ),
                    onTap: () {
                      onSelected(
                        place,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedPlaceCard
    extends StatelessWidget {
  const _SelectedPlaceCard({
    required this.place,
    required this.kindLabel,
    required this.distanceLabel,
    required this.openingLabel,
    required this.directionsLabel,
    required this.callLabel,
    required this.sourceLabel,
    required this.onDirections,
    required this.onClose,
    this.onCall,
  });

  final NearbyHealthcarePlace place;

  final String kindLabel;

  final String distanceLabel;

  final String openingLabel;

  final String directionsLabel;

  final String callLabel;

  final String sourceLabel;

  final VoidCallback onDirections;

  final VoidCallback onClose;

  final VoidCallback? onCall;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      PharmaLensDecorations
          .surfaceCard(
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        isDark:
        isDark,
      ),
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PlaceIcon(
                isPharmacy:
                place.isPharmacy,
              ),

              const SizedBox(
                width:
                11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines:
                      2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      TextStyle(
                        color:
                        palette.textPrimary,
                        fontSize:
                        16,
                        height:
                        1.2,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                      4,
                    ),

                    Text(
                      '$kindLabel • $distanceLabel',
                      style:
                      const TextStyle(
                        color:
                        PharmaLensColors.info,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed:
                onClose,
                icon:
                Icon(
                  Icons.close_rounded,
                  color:
                  palette.textPrimary,
                ),
              ),
            ],
          ),

          if (place.address
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height:
              9,
            ),

            Text(
              place.address.trim(),
              maxLines:
              2,
              overflow:
              TextOverflow.ellipsis,
              style:
              TextStyle(
                color:
                palette.textSecondary,
                height:
                1.35,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(
            height:
            10,
          ),

          Wrap(
            spacing:
            7,
            runSpacing:
            7,
            children: [
              _PlaceInfoPill(
                icon:
                Icons.public_rounded,
                label:
                sourceLabel,
                foreground:
                PharmaLensColors.info,
              ),

              if (openingLabel
                  .trim()
                  .isNotEmpty)
                _PlaceInfoPill(
                  icon:
                  place.openNow ==
                      true
                      ? Icons
                      .schedule_rounded
                      : Icons
                      .schedule_outlined,
                  label:
                  openingLabel,
                  foreground:
                  place.openNow ==
                      true
                      ? PharmaLensColors
                      .success
                      : PharmaLensColors
                      .warning,
                ),

              if (place.rating >
                  0)
                _PlaceInfoPill(
                  icon:
                  Icons.star_rounded,
                  label:
                  place.userRatingCount >
                      0
                      ? '${place.rating.toStringAsFixed(1)} (${place.userRatingCount})'
                      : place.rating
                      .toStringAsFixed(
                    1,
                  ),
                  foreground:
                  PharmaLensColors.warning,
                ),
            ],
          ),

          const SizedBox(
            height:
            13,
          ),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                  onDirections,
                  icon:
                  const Icon(
                    Icons
                        .directions_rounded,
                  ),
                  label:
                  Text(
                    directionsLabel,
                  ),
                ),
              ),

              if (onCall !=
                  null) ...[
                const SizedBox(
                  width:
                  8,
                ),

                FilledButton.tonalIcon(
                  onPressed:
                  onCall,
                  icon:
                  const Icon(
                    Icons.call_rounded,
                  ),
                  label:
                  Text(
                    callLabel,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceInfoPill
    extends StatelessWidget {
  const _PlaceInfoPill({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final IconData icon;

  final String label;

  final Color foreground;

  @override
  Widget build(
      BuildContext context,
      ) {
    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,
        vertical:
        6,
      ),
      decoration:
      BoxDecoration(
        color:
        foreground.withValues(
          alpha:
          isDark
              ? 0.14
              : 0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
            14,
            color:
            foreground,
          ),

          const SizedBox(
            width:
            5,
          ),

          Text(
            label,
            style:
            TextStyle(
              color:
              foreground,
              fontSize:
              10.8,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton
    extends StatelessWidget {
  const _MapButton({
    required this.heroTag,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onPressed,
    this.loading = false,
  });

  final Object heroTag;

  final IconData icon;

  final Color foreground;

  final Color background;

  final VoidCallback? onPressed;

  final bool loading;

  @override
  Widget build(
      BuildContext context,
      ) {
    return FloatingActionButton.small(
      heroTag:
      heroTag,
      backgroundColor:
      background,
      foregroundColor:
      foreground,
      onPressed:
      onPressed,
      child:
      loading
          ? const Padding(
        padding:
        EdgeInsets.all(
          10,
        ),
        child:
        CircularProgressIndicator(
          strokeWidth:
          2,
        ),
      )
          : Icon(
        icon,
      ),
    );
  }
}

class _PlaceAvatar
    extends StatelessWidget {
  const _PlaceAvatar({
    required this.isPharmacy,
  });

  final bool isPharmacy;

  @override
  Widget build(
      BuildContext context,
      ) {
    final color =
    isPharmacy
        ? PharmaLensColors.info
        : const Color(
      0xFF8B6EF6,
    );

    return CircleAvatar(
      backgroundColor:
      color.withValues(
        alpha:
        0.13,
      ),
      child: Icon(
        isPharmacy
            ? Icons
            .local_pharmacy_rounded
            : Icons
            .medical_services_rounded,
        color:
        color,
      ),
    );
  }
}

class _PlaceIcon
    extends StatelessWidget {
  const _PlaceIcon({
    required this.isPharmacy,
  });

  final bool isPharmacy;

  @override
  Widget build(
      BuildContext context,
      ) {
    final color =
    isPharmacy
        ? PharmaLensColors.info
        : const Color(
      0xFF8B6EF6,
    );

    return Container(
      width:
      50,
      height:
      50,
      decoration:
      BoxDecoration(
        color:
        color.withValues(
          alpha:
          0.13,
        ),
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),
      child: Icon(
        isPharmacy
            ? Icons
            .local_pharmacy_rounded
            : Icons
            .medical_services_rounded,
        color:
        color,
      ),
    );
  }
}

class _LocationAccessException
    implements Exception {
  const _LocationAccessException(
      this.message,
      );

  final String message;

  @override
  String toString() {
    return message;
  }
}