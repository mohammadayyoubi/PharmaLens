import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_text.dart';
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

  static const MapCoordinates _beirutFallback =
  MapCoordinates(
    33.8938,
    35.5018,
  );

  final NearbyHealthcareService _service =
  NearbyHealthcareService();

  final UniversalMapController _universalMapController = UniversalMapController();

  Position? _userPosition;

  NearbyHealthcarePlace? _selectedPlace;

  List<NearbyHealthcarePlace> _places =
  const <NearbyHealthcarePlace>[];

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


        _isLoading =
        false;

        _isRefreshing =
        false;

        if (nearest.isEmpty) {
          _errorMessage =
              appText(_isArabic).noPharmaciesWereFoundWithin5;
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
            appText(_isArabic).nearbyHealthcareSearchIsTemporarilyUnavailable;
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
        appText(_isArabic).yourLocationCouldNotBeAccessed,
      );
    }

    if (!serviceEnabled) {
      if (mounted) {
        await _showLocationDisabledDialog();
      }

      throw _LocationAccessException(
        appText(_isArabic).locationServicesAreDisabledEnableGps,
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
        appText(_isArabic).locationPermissionCouldNotBeChecked,
      );
    }

    if (permission ==
        LocationPermission.denied) {
      throw _LocationAccessException(
        appText(_isArabic).locationPermissionIsRequiredToFind,
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      if (mounted) {
        await _showPermissionBlockedDialog();
      }

      throw _LocationAccessException(
        appText(_isArabic).locationPermissionIsBlockedEnableIt,
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
        appText(_isArabic).yourCurrentLocationCouldNotBe,
      );
    }
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

    });

    _universalMapController.animateTo(
      place.latitude,
      place.longitude,
      zoom: 16,
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
      return appText(_isArabic).nearby;
    }

    final meters =
    _distanceTo(
      place,
      position,
    );

    if (meters <
        1000) {
      return appText(_isArabic).m(meters.round());
    }

    final kilometers =
        meters /
            1000;

    return appText(_isArabic).km(kilometers.toStringAsFixed(1));
  }

  String _kindLabel(
      NearbyHealthcarePlace place,
      ) {
    if (place.isPharmacy) {
      return appText(_isArabic).pharmacy;
    }

    return appText(_isArabic).medicalCenter;
  }

  String _openingLabel(
      NearbyHealthcarePlace place,
      ) {
    switch (place.openNow) {
      case true:
        return appText(_isArabic).openNow;

      case false:
        return appText(_isArabic).closedNow;

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
      appText(_isArabic).couldNotOpenDirections,
    );
  }

  Future<void> _callPlace(
      NearbyHealthcarePlace place,
      ) async {
    final phone =
    place.phone.trim();

    if (phone.isEmpty) {
      _showMessage(
        appText(_isArabic).noPhoneNumberIsAvailableFor,
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
      appText(_isArabic).couldNotOpenThePhoneApplication,
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
            appText(_isArabic).enableLocation,
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
            appText(_isArabic).enableGpsToFindTheClosest,
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
                appText(_isArabic).cancel,
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
                appText(_isArabic).openSettings,
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
            appText(_isArabic).locationPermission,
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
            appText(_isArabic).locationPermissionIsBlockedEnableIt,
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
                appText(_isArabic).cancel,
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
                appText(_isArabic).openSettings,
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
                        appText(_isArabic).nearbyHealthcare,
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
          Tooltip(
            message: appText(_isArabic).aiAssistant,
            child: _MapButton(
              heroTag: 'healthcare_assistant',
              icon: Icons.auto_awesome_rounded,
              foreground: Colors.white,
              background: PharmaLensColors.teal,
              onPressed: () => ChatbotView.showAsBottomSheet(context),
            ),
          ),

          const SizedBox(
            height:
            9,
          ),

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
        appText(_isArabic).directions2,
        callLabel:
        appText(_isArabic).call,
        sourceLabel:
        appText(_isArabic).googleListing,
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
              appText(_isArabic).retry2,
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
                  appText(_isArabic).findingNearbyHealthcare,
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

    final userPosition =
        _userPosition;

    // OpenStreetMap on every platform: Google's map SDK needs a billing
    // account, which is not available to us.
    final initialCenter = userPosition == null
        ? _beirutFallback
        : MapCoordinates(
            userPosition.latitude,
            userPosition.longitude,
          );

    final userCoords = userPosition == null
        ? null
        : MapCoordinates(
            userPosition.latitude,
            userPosition.longitude,
          );

    // No floating assistant button here: it covered the Call button of the
    // place card. The assistant is the first of the map buttons instead.
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
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
                  appText(isArabic).closestToYou,
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
                  appText(isArabic).noNearbyResultsYet,
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