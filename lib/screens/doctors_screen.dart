import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/doctor.dart';
import '../services/doctors_service.dart';
import '../theme/pharmalens_theme.dart';
import '../services/hospital_contact_service.dart';
import '../utils/formatters.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/responsive.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() {
    return _DoctorsScreenState();
  }
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  static const int _pageSize = 50;

  static const Duration _searchDelay = Duration(milliseconds: 350);

  final DoctorsService _service = DoctorsService();

  final TextEditingController _searchController = TextEditingController();

  List<Doctor> _doctors = <Doctor>[];

  DoctorsFilterMetadata _metadata = const DoctorsFilterMetadata.empty();

  String _selectedGender = '';
  String _selectedSpecialty = '';

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;

  String _error = '';

  Timer? _searchDebounce;

  int _requestSerial = 0;

  bool get _isArabic {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  bool get _hasFilters {
    return _searchController.text.trim().isNotEmpty ||
        _selectedGender.isNotEmpty ||
        _selectedSpecialty.isNotEmpty;
  }

  String _t({required String en, required String ar}) {
    return _isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitial();
      }
    });
  }

  @override
  void dispose() {
    _requestSerial++;

    _searchDebounce?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final metadata = await _service.loadFilterMetadata();

      if (!mounted) {
        return;
      }

      setState(() {
        _metadata = metadata;
      });

      await _loadDoctors(reset: true);
    } on DoctorsServiceException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        _error = _t(
          en: 'Could not load the doctors directory.',
          ar: 'تعذر تحميل دليل الأطباء.',
        );
      });
    }
  }

  Future<void> _refresh() async {
    _searchDebounce?.cancel();

    try {
      final metadata = await _service.loadFilterMetadata();

      if (!mounted) {
        return;
      }

      setState(() {
        _metadata = metadata;
      });

      await _loadDoctors(reset: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _t(
          en: 'Could not refresh doctors.',
          ar: 'تعذر تحديث الأطباء.',
        );
      });
    }
  }

  Future<void> _loadDoctors({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasMore)) {
      return;
    }

    final requestId = ++_requestSerial;

    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = false;
        _doctors = <Doctor>[];
        _error = '';
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final result = await _service.searchDoctorsPage(
        query: _searchController.text.trim(),
        specialty: _selectedSpecialty,
        gender: _selectedGender,
        limit: _pageSize,
        offset: reset ? 0 : _doctors.length,
      );

      if (!mounted || requestId != _requestSerial) {
        return;
      }

      setState(() {
        _doctors = reset ? result : <Doctor>[..._doctors, ...result];

        _hasMore = result.length == _pageSize;

        _loading = false;
        _loadingMore = false;
        _error = '';
      });
    } on DoctorsServiceException catch (error) {
      if (!mounted || requestId != _requestSerial) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestSerial) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;

        _error = _t(en: 'Could not load doctors.', ar: 'تعذر تحميل الأطباء.');
      });
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();

    setState(() {});

    _searchDebounce = Timer(_searchDelay, () {
      _loadDoctors(reset: true);
    });
  }

  void _setGender(String gender) {
    if (_selectedGender == gender) {
      return;
    }

    setState(() {
      _selectedGender = gender;
    });

    _loadDoctors(reset: true);
  }

  void _clearFilters() {
    _searchDebounce?.cancel();

    _searchController.clear();

    setState(() {
      _selectedGender = '';
      _selectedSpecialty = '';
    });

    _loadDoctors(reset: true);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 300) {
      _loadDoctors(reset: false);
    }

    return false;
  }

  String _specialtyLabel(String specialty) {
    if (!_isArabic) {
      return specialty;
    }

    final arabic = _metadata.specialtyArabic(specialty);

    if (arabic.trim().isNotEmpty) {
      return arabic.trim();
    }

    return specialty;
  }

  Future<void> _pickSpecialty() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PharmaLensTheme.paletteOf(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return _SpecialtyPickerSheet(
          specialties: _metadata.specialties,
          counts: _metadata.specialtyCounts,
          selected: _selectedSpecialty,
          isArabic: _isArabic,
          displayValue: _specialtyLabel,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedSpecialty = result;
    });

    _loadDoctors(reset: true);
  }

  Future<void> _openUri(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);

      if (!opened && mounted) {
        _showActionError();
      }
    } catch (_) {
      if (mounted) {
        _showActionError();
      }
    }
  }

  void _showActionError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _t(en: 'Could not open this action.', ar: 'تعذر فتح هذا الخيار.'),
          ),
        ),
      );
  }

  String _dialablePhone(String raw) {
    var value = raw.trim();

    if (value.isEmpty) {
      return '';
    }

    value = value
        .split(RegExp(r'\b(?:ext|extension)\.?\b', caseSensitive: false))
        .first
        .split('/')
        .first
        .trim();

    final hasPlus = value.startsWith('+');

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return '';
    }

    return hasPlus ? '+$digits' : digits;
  }

  Future<void> _call(String phone) async {
    final value = _dialablePhone(phone);

    if (value.isEmpty) {
      return;
    }

    await _openUri(Uri(scheme: 'tel', path: value));
  }

  Future<void> _email(String email) async {
    final value = email.trim();

    if (value.isEmpty) {
      return;
    }

    await _openUri(Uri(scheme: 'mailto', path: value));
  }

  Future<void> _whatsapp(String phone) async {
    var value = phone.trim().split('/').first;

    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      digits = '961${digits.substring(1)}';
    }

    if (digits.length == 7 || digits.length == 8) {
      digits = '961$digits';
    }

    if (digits.isEmpty) {
      return;
    }

    await _openUri(Uri.https('wa.me', '/$digits'));
  }

  Future<void> _directions(Doctor doctor) async {
    late final Uri uri;

    if (doctor.hasCoordinates) {
      uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
        'api': '1',
        'destination': '${doctor.latitude},${doctor.longitude}',
        'travelmode': 'driving',
      });
    } else {
      final query = <String>[
        doctor.fullName,
        doctor.displayFacility,
        doctor.displayAddress,
        'Lebanon',
      ].where((value) => value.trim().isNotEmpty).join(' ');

      uri = Uri.https('www.google.com', '/maps/search/', <String, String>{
        'api': '1',
        'query': query,
      });
    }

    await _openUri(uri);
  }

  Future<void> _source(Doctor doctor) async {
    final uri = doctor.sourceUri;

    if (uri == null) {
      return;
    }

    await _openUri(uri);
  }

  Future<void> _openDoctor(Doctor doctor) async {
    final palette = PharmaLensTheme.paletteOf(context);

    Widget sheet(bool dialog) {
      return _DoctorProfileSheet(
        doctor: doctor,
        isArabic: _isArabic,
        asDialog: dialog,
        onCall: doctor.hasPhone
            ? () {
                _call(doctor.phone);
              }
            : null,
        onWhatsapp: doctor.hasWhatsapp
            ? () {
                _whatsapp(doctor.whatsapp);
              }
            : null,
        onEmail: doctor.hasEmail
            ? () {
                _email(doctor.email);
              }
            : null,
        onDirections: doctor.hasCoordinates || doctor.displayAddress.isNotEmpty
            ? () {
                _directions(doctor);
              }
            : null,
        onSource: doctor.hasSourceUrl
            ? () {
                _source(doctor);
              }
            : null,
        onCallNumber: _call,
        onOpenUri: _openUri,
      );
    }

    if (MediaQuery.sizeOf(context).width >= 900) {
      await showDialog<void>(
        context: context,
        builder: (_) {
          return Dialog(
            backgroundColor: palette.surface,
            insetPadding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600,
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              child: sheet(true),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return sheet(false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: const FloatingChatbotButton(),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final gutter = Breakpoints.gutter(constraints.maxWidth);

              final results = RefreshIndicator(
                onRefresh: _refresh,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScroll,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      if (!wide)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
                            child: _buildFilters(),
                          ),
                        ),
                      SliverToBoxAdapter(child: _buildResultsBar(gutter)),
                      ..._buildResults(gutter: gutter, wide: wide),
                    ],
                  ),
                ),
              );

              if (!wide) {
                return results;
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 340,
                        child: SingleChildScrollView(
                          padding: EdgeInsetsDirectional.fromSTEB(gutter, 12, 0, 24),
                          child: _buildFilters(),
                        ),
                      ),
                      Expanded(child: results),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final palette = PharmaLensTheme.paletteOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const AdaptiveBackButton(),
            Expanded(
              child: _DirectoryHeader(
                total: _metadata.totalDoctors,
                isArabic: _isArabic,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _searchController,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            _scheduleSearch();
          },
          onSubmitted: (_) {
            _searchDebounce?.cancel();

            _loadDoctors(reset: true);
          },
          decoration: InputDecoration(
            hintText: _t(
              en: 'Search doctor, specialty or hospital',
              ar: 'ابحث عن طبيب أو اختصاص أو مستشفى',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: _t(en: 'Clear search', ar: 'مسح البحث'),
                    onPressed: () {
                      _searchController.clear();

                      _scheduleSearch();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        _SpecialtyButton(
          value: _selectedSpecialty.isEmpty
              ? _t(en: 'All specialties', ar: 'كل الاختصاصات')
              : _specialtyLabel(_selectedSpecialty),
          active: _selectedSpecialty.isNotEmpty,
          isArabic: _isArabic,
          onTap: _pickSpecialty,
        ),

        const SizedBox(height: 12),

        Text(
          _t(en: 'Doctor gender', ar: 'جنس الطبيب'),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: <Widget>[
            Expanded(
              child: _GenderButton(
                icon: Icons.groups_rounded,
                label: _t(en: 'Any', ar: 'الكل'),
                selected: _selectedGender.isEmpty,
                onTap: () {
                  _setGender('');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GenderButton(
                icon: Icons.female_rounded,
                label: _t(en: 'Female', ar: 'طبيبة'),
                selected: _selectedGender == 'Female',
                onTap: () {
                  _setGender('Female');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GenderButton(
                icon: Icons.male_rounded,
                label: _t(en: 'Male', ar: 'طبيب'),
                selected: _selectedGender == 'Male',
                onTap: () {
                  _setGender('Male');
                },
              ),
            ),
          ],
        ),

        if (_selectedGender.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _t(
              en: 'The official list has no gender field, so it is estimated from the first name. About 1 in 10 doctors cannot be estimated and only appear under "Any".',
              ar: 'لا تتضمن اللائحة الرسمية الجنس، لذا يُقدَّر من الاسم الأول. حوالي طبيب من كل 10 لا يمكن تقديره ويظهر فقط ضمن "الكل".',
            ),
            style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
          ),
        ],

        if (_hasFilters) ...<Widget>[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: Text(_t(en: 'Clear filters', ar: 'مسح الفلاتر')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsBar(double gutter) {
    if (_loading && _doctors.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = PharmaLensTheme.paletteOf(context);

    final moreLabel = _hasMore ? '+' : '';

    final text = _hasFilters
        ? _t(
            en: '${_doctors.length}$moreLabel matching doctors',
            ar: '${_doctors.length}$moreLabel طبيب/ة مطابقون',
          )
        : _t(
            en: 'Showing ${_doctors.length}$moreLabel of ${formatCount(_metadata.totalDoctors)}',
            ar: 'عرض ${_doctors.length}$moreLabel من أصل ${formatCount(_metadata.totalDoctors)}',
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (_loadingMore)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildResults({required double gutter, required bool wide}) {
    if (_loading && _doctors.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error.isNotEmpty && _doctors.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icons.error_outline_rounded,
            title: _t(en: 'Could not load doctors', ar: 'تعذر تحميل الأطباء'),
            subtitle: _error,
            buttonLabel: _t(en: 'Try again', ar: 'إعادة المحاولة'),
            onPressed: _refresh,
          ),
        ),
      ];
    }

    if (_doctors.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icons.search_off_rounded,
            title: _t(en: 'No matching doctors', ar: 'لا يوجد أطباء مطابقون'),
            subtitle: _t(
              en: 'Try another name, specialty or hospital.',
              ar: 'جرّب اسمًا أو اختصاصًا أو مستشفى مختلفًا.',
            ),
            buttonLabel: _t(en: 'Clear filters', ar: 'مسح الفلاتر'),
            onPressed: _clearFilters,
          ),
        ),
      ];
    }

    Widget card(Doctor doctor) {
      return _DoctorCard(
        doctor: doctor,
        isArabic: _isArabic,
        onTap: () {
          _openDoctor(doctor);
        },
        onCall: doctor.hasPhone
            ? () {
                _call(doctor.phone);
              }
            : null,
        onWhatsapp: doctor.hasWhatsapp
            ? () {
                _whatsapp(doctor.whatsapp);
              }
            : null,
      );
    }

    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 0),
        sliver: wide
            ? SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisExtent: 150,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _doctors.length,
                itemBuilder: (context, index) => card(_doctors[index]),
              )
            : SliverList.separated(
                itemCount: _doctors.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => card(_doctors[index]),
              ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 88),
          child: _PaginationFooter(
            loading: _loadingMore,
            hasMore: _hasMore,
            isArabic: _isArabic,
            onLoad: () {
              _loadDoctors(reset: false);
            },
          ),
        ),
      ),
    ];
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.total,
    required this.isArabic,
  });

  final int total;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            isArabic ? 'دليل الأطباء' : 'Doctors',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isArabic
              ? '${formatCount(total)} طبيب مسجل في نقابة الأطباء في لبنان'
              : '${formatCount(total)} doctors registered with the Lebanese Order of Physicians',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Material(
      color: selected ? palette.tealSurface : palette.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? PharmaLensColors.teal.withValues(alpha: 0.27)
                  : palette.border,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                size: 19,
                color: selected ? PharmaLensColors.teal : palette.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? PharmaLensColors.teal : palette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialtyButton extends StatelessWidget {
  const _SpecialtyButton({
    required this.value,
    required this.active,
    required this.isArabic,
    required this.onTap,
  });

  final String value;
  final bool active;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Material(
      color: active ? palette.tealSurface : palette.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? PharmaLensColors.teal.withValues(alpha: 0.27)
                  : palette.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.medical_services_outlined,
                color: active ? PharmaLensColors.teal : palette.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isArabic ? 'الاختصاص' : 'Specialty',
                      style: TextStyle(color: palette.textMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? PharmaLensColors.teal
                            : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.isArabic,
    required this.onTap,
    this.onCall,
    this.onWhatsapp,
  });

  final Doctor doctor;
  final bool isArabic;
  final VoidCallback onTap;

  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    final name = doctor.localizedName(isArabic: isArabic);

    final specialty = doctor.localizedSpecialty(isArabic: isArabic);

    final accent = doctor.isFemale
        ? const Color(0xFFD95A91)
        : PharmaLensColors.teal;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: palette.border),
            boxShadow: palette.cardShadow,
          ),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      doctor.initials,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (specialty.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            specialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PharmaLensColors.teal,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (doctor.subspecialty.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            doctor.subspecialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textMuted,
                  ),
                ],
              ),
              ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        doctor.hospitals.isEmpty
                            ? Icons.storefront_outlined
                            : Icons.local_hospital_outlined,
                        color: PharmaLensColors.teal,
                        size: 16,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          doctor.facilityLabel(isArabic: isArabic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (onCall != null || onWhatsapp != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (onCall != null)
                      Expanded(
                        child: _DoctorAction(
                          icon: Icons.call_rounded,
                          label: isArabic ? 'اتصال' : 'Call',
                          onTap: onCall!,
                        ),
                      ),
                    if (onCall != null && onWhatsapp != null)
                      const SizedBox(width: 8),
                    if (onWhatsapp != null)
                      Expanded(
                        child: _DoctorAction(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          onTap: onWhatsapp!,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorAction extends StatelessWidget {
  const _DoctorAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Material(
      color: palette.tealSurface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 17, color: PharmaLensColors.teal),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: PharmaLensColors.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorProfileSheet extends StatelessWidget {
  const _DoctorProfileSheet({
    required this.doctor,
    required this.isArabic,
    required this.onCallNumber,
    required this.onOpenUri,
    this.asDialog = false,
    this.onCall,
    this.onWhatsapp,
    this.onEmail,
    this.onDirections,
    this.onSource,
  });

  final Doctor doctor;
  final bool isArabic;
  final bool asDialog;

  final Future<void> Function(String phone) onCallNumber;
  final Future<void> Function(Uri uri) onOpenUri;

  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onEmail;
  final VoidCallback? onDirections;
  final VoidCallback? onSource;

  String _t({required String en, required String ar}) {
    return isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    final name = doctor.localizedName(isArabic: isArabic);

    return SizedBox(
      height: asDialog ? null : MediaQuery.sizeOf(context).height * 0.85,
      child: ListView(
        shrinkWrap: asDialog,
        padding: EdgeInsets.fromLTRB(16, asDialog ? 16 : 0, 16, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: PharmaLensDecorations.heroCard(
              borderRadius: BorderRadius.circular(24),
              isDark: PharmaLensTheme.isDark(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  doctor.localizedSpecialty(isArabic: isArabic),
                  style: const TextStyle(
                    color: PharmaLensColors.brightCyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (doctor.subspecialty.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    doctor.subspecialty,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (doctor.gender.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    doctor.genderEstimated
                        ? '${doctor.localizedGender(isArabic: isArabic)} · ${_t(en: 'estimated from name', ar: 'مقدّر من الاسم')}'
                        : doctor.localizedGender(isArabic: isArabic),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          _ContactSection(
            doctor: doctor,
            isArabic: isArabic,
            onCallNumber: onCallNumber,
            onOpenUri: onOpenUri,
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onCall != null)
                _ProfileAction(
                  icon: Icons.call_rounded,
                  label: _t(en: 'Call', ar: 'اتصال'),
                  onTap: onCall!,
                ),
              if (onWhatsapp != null)
                _ProfileAction(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  onTap: onWhatsapp!,
                ),
              if (onEmail != null)
                _ProfileAction(
                  icon: Icons.email_outlined,
                  label: _t(en: 'Email', ar: 'البريد'),
                  onTap: onEmail!,
                ),
              if (onDirections != null)
                _ProfileAction(
                  icon: Icons.directions_outlined,
                  label: _t(en: 'Directions', ar: 'الطريق'),
                  onTap: onDirections!,
                ),
            ],
          ),

          const SizedBox(height: 12),

          _InformationCard(
            title: _t(en: 'Professional information', ar: 'المعلومات المهنية'),
            items: <_InfoItem>[
              _InfoItem(
                label: _t(en: 'Specialty', ar: 'الاختصاص'),
                value: doctor.localizedSpecialty(isArabic: isArabic),
              ),
              _InfoItem(
                label: _t(en: 'Subspecialty', ar: 'الاختصاص الفرعي'),
                value: doctor.subspecialty,
              ),
              _InfoItem(
                label: _t(en: 'Hospital / Clinic', ar: 'المستشفى / العيادة'),
                value: doctor.facilityLabel(isArabic: isArabic),
              ),
              _InfoItem(
                label: _t(en: 'Location', ar: 'الموقع'),
                value: doctor.displayLocation,
              ),
            ],
          ),

          const SizedBox(height: 12),

          _InformationCard(
            title: _t(en: 'Contact', ar: 'التواصل'),
            items: <_InfoItem>[
              _InfoItem(
                label: _t(en: 'Phone', ar: 'الهاتف'),
                value: doctor.phone,
              ),
              _InfoItem(label: 'WhatsApp', value: doctor.whatsapp),
              _InfoItem(
                label: _t(en: 'Email', ar: 'البريد'),
                value: doctor.email,
              ),
            ],
          ),

          const SizedBox(height: 12),

          _InformationCard(
            title: _t(en: 'Data source', ar: 'مصدر البيانات'),
            items: <_InfoItem>[
              _InfoItem(
                label: _t(en: 'Source', ar: 'المصدر'),
                value: doctor.displaySource,
              ),
              _InfoItem(
                label: _t(en: 'Doctor ID', ar: 'رقم الطبيب'),
                value: doctor.doctorCode,
              ),
            ],
            footer: onSource == null
                ? null
                : TextButton.icon(
                    onPressed: onSource,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(_t(en: 'Open source', ar: 'فتح المصدر')),
                  ),
          ),

          const SizedBox(height: 12),

          Text(
            _t(
              en: 'The Order of Physicians list does not publish doctors\' phone numbers or clinic addresses. Hospital contacts come from Google Maps and can change; confirm before visiting.',
              ar: 'لا تنشر لائحة نقابة الأطباء أرقام هواتف الأطباء أو عناوين العيادات. معلومات المستشفيات من خرائط Google وقد تتغير؛ تأكد قبل الزيارة.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PharmaLensTheme.paletteOf(context).textMuted,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: _DoctorAction(icon: icon, label: label, onTap: onTap),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.title,
    required this.items,
    this.footer,
  });

  final String title;
  final List<_InfoItem> items;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    final visibleItems = items
        .where((item) => item.value.trim().isNotEmpty)
        .toList();

    if (visibleItems.isEmpty && footer == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: palette.border),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...visibleItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 105,
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _SpecialtyPickerSheet extends StatefulWidget {
  const _SpecialtyPickerSheet({
    required this.specialties,
    required this.counts,
    required this.selected,
    required this.isArabic,
    required this.displayValue,
  });

  final List<String> specialties;
  final Map<String, int> counts;
  final String selected;
  final bool isArabic;

  final String Function(String) displayValue;

  @override
  State<_SpecialtyPickerSheet> createState() => _SpecialtyPickerSheetState();
}

class _SpecialtyPickerSheetState extends State<_SpecialtyPickerSheet> {
  final TextEditingController _controller = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();

    final values = widget.specialties.where((specialty) {
      if (query.isEmpty) {
        return true;
      }

      return specialty.toLowerCase().contains(query) ||
          widget.displayValue(specialty).toLowerCase().contains(query);
    }).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.76,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.isArabic ? 'اختيار الاختصاص' : 'Select specialty',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: widget.isArabic
                        ? 'ابحث عن اختصاص'
                        : 'Search specialty',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                _SpecialtyTile(
                  title: widget.isArabic ? 'كل الاختصاصات' : 'All specialties',
                  count: 0,
                  selected: widget.selected.isEmpty,
                  onTap: () {
                    Navigator.of(context).pop('');
                  },
                ),
                const SizedBox(height: 7),
                ...values.map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _SpecialtyTile(
                      title: widget.displayValue(value),
                      count: widget.counts[value] ?? 0,
                      selected: widget.selected == value,
                      onTap: () {
                        Navigator.of(context).pop(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  const _SpecialtyTile({
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Material(
      color: selected ? palette.tealSurface : palette.surfaceSoft,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? PharmaLensColors.teal : palette.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected
                        ? PharmaLensColors.teal
                        : palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (count > 0)
                Text('$count', style: TextStyle(color: palette.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.loading,
    required this.hasMore,
    required this.isArabic,
    required this.onLoad,
  });

  final bool loading;
  final bool hasMore;
  final bool isArabic;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Text(
            isArabic ? 'نهاية النتائج' : 'End of results',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onLoad,
          icon: const Icon(Icons.expand_more_rounded),
          label: Text(isArabic ? 'تحميل المزيد' : 'Load more'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 58, color: PharmaLensColors.brightCyan),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 15),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

/// How to reach the doctor. The source list has no doctor phone numbers or
/// clinic addresses, so the doctor's own details are shown when present and
/// otherwise the public switchboard and location of their hospital(s).
class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.doctor,
    required this.isArabic,
    required this.onCallNumber,
    required this.onOpenUri,
  });

  final Doctor doctor;
  final bool isArabic;
  final Future<void> Function(String phone) onCallNumber;
  final Future<void> Function(Uri uri) onOpenUri;

  String _t({required String en, required String ar}) => isArabic ? ar : en;

  Uri _mapsSearch(String query) {
    return Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': query,
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final hospitals = doctor.hospitals.take(3).toList();
    final service = HospitalContactService();

    final children = <Widget>[];

    if (doctor.hasPhone || doctor.hasCoordinates) {
      children.add(
        _ContactRow(
          icon: Icons.person_pin_circle_outlined,
          title: _t(en: 'Doctor', ar: 'الطبيب'),
          subtitle: [doctor.phone, doctor.displayAddress].where((v) => v.trim().isNotEmpty).join('\n'),
          onCall: doctor.hasPhone ? () => onCallNumber(doctor.phone) : null,
          onMap: doctor.hasCoordinates
              ? () => onOpenUri(_mapsSearch('${doctor.latitude},${doctor.longitude}'))
              : null,
          isArabic: isArabic,
        ),
      );
    }

    for (final hospital in hospitals) {
      children.add(
        FutureBuilder<HospitalContact?>(
          future: service.find(hospital, languageCode: isArabic ? 'ar' : 'en'),
          builder: (context, snapshot) {
            final contact = snapshot.data;
            final loading = snapshot.connectionState != ConnectionState.done;

            return _ContactRow(
              icon: Icons.local_hospital_outlined,
              title: hospital,
              subtitle: loading
                  ? _t(en: 'Looking up hospital contact...', ar: 'جارٍ البحث عن معلومات المستشفى...')
                  : contact == null
                      ? _t(en: 'Contact not found. Search it on the map.', ar: 'لم يتم العثور على المعلومات. ابحث على الخريطة.')
                      : [contact.phone, contact.address].where((v) => v.isNotEmpty).join('\n'),
              loading: loading,
              onCall: contact != null && contact.hasPhone ? () => onCallNumber(contact.phone) : null,
              onMap: () => onOpenUri(
                contact != null && contact.mapsUrl.isNotEmpty
                    ? Uri.parse(contact.mapsUrl)
                    : _mapsSearch('$hospital hospital Lebanon'),
              ),
              isArabic: isArabic,
            );
          },
        ),
      );
    }

    if (hospitals.isEmpty && !doctor.hasPhone) {
      final query = '${doctor.fullName} ${doctor.specialtyEn} Lebanon';
      children.add(
        _ContactRow(
          icon: Icons.storefront_outlined,
          title: _t(en: 'Private clinic', ar: 'عيادة خاصة'),
          subtitle: _t(
            en: 'The clinic address is not in the official list. You can search for it:',
            ar: 'عنوان العيادة غير موجود في اللائحة الرسمية. يمكنك البحث عنه:',
          ),
          onMap: () => onOpenUri(_mapsSearch(query)),
          onWeb: () => onOpenUri(Uri.https('www.google.com', '/search', <String, String>{'q': query})),
          isArabic: isArabic,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: palette.border),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _t(en: 'Contact & location', ar: 'التواصل والموقع'),
            style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 18, color: palette.borderSoft),
            children[i],
          ],
          if (!service.isConfigured && hospitals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _t(
                en: 'Hospital phone lookup needs a Google Places key in the app configuration.',
                ar: 'البحث عن هاتف المستشفى يحتاج إلى مفتاح Google Places في إعدادات التطبيق.',
              ),
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isArabic,
    this.loading = false,
    this.onCall,
    this.onMap,
    this.onWeb,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isArabic;
  final bool loading;
  final VoidCallback? onCall;
  final VoidCallback? onMap;
  final VoidCallback? onWeb;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: PharmaLensColors.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4)),
                  ],
                ],
              ),
            ),
            if (loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (onCall != null || onMap != null || onWeb != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onCall != null)
                _ProfileAction(icon: Icons.call_rounded, label: isArabic ? 'اتصال' : 'Call', onTap: onCall!),
              if (onMap != null)
                _ProfileAction(icon: Icons.map_outlined, label: isArabic ? 'الخريطة' : 'Map', onTap: onMap!),
              if (onWeb != null)
                _ProfileAction(icon: Icons.travel_explore_rounded, label: isArabic ? 'بحث' : 'Search web', onTap: onWeb!),
            ],
          ),
        ],
      ],
    );
  }
}
