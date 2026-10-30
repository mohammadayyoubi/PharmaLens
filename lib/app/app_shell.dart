import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_text.dart';
import '../screens/doctors_screen.dart';
import '../screens/dose_screen.dart';
import '../screens/home_screen.dart';
import '../screens/medicine_details_screen.dart';
import '../screens/medicine_search_screen.dart';
import '../screens/my_health_screen.dart';
import '../screens/pharmacies_map_screen.dart';
import '../screens/settings_screen.dart';
import '../services/connectivity_service.dart';
import '../services/moph_medicine_service.dart';
import '../services/prescription_history_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';
import '../utils/formatters.dart';
import '../widgets/responsive.dart';

enum AppTab {
  home,
  medicines,
  doctors,
  pharmacies,
  myHealth,
  settings,
}

/// Lets any screen switch sections without knowing the layout.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.currentTab,
    required this.selectTab,
    required super.child,
  });

  final AppTab currentTab;
  final void Function(AppTab tab) selectTab;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) => currentTab != oldWidget.currentTab;
}

/// Adaptive app frame: bottom navigation on phones, a rail on tablets and a
/// sidebar on desktop. Each section keeps its own navigator, so pages opened
/// from a section (analysis, medicine details) stay beside the sidebar on
/// desktop and each tab remembers where the user was.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.home;

  @override
  void initState() {
    super.initState();

    MophMedicineService().datasetRevision.addListener(_onPricesUpdated);
    ReminderService().pendingDose.addListener(_onDoseDue);
    // A reminder notification may have launched the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDoseDue());

    // Web links such as /?tab=doctors open that section directly.
    if (kIsWeb) {
      final requested = Uri.base.queryParameters['tab'];
      for (final tab in AppTab.values) {
        if (tab.name == requested) {
          _tab = tab;
          _visited.add(tab);
        }
      }

      // /?tab=medicines&medicine=<MOPH code> opens that product's page.
      final medicine = MophMedicineService().findById(Uri.base.queryParameters['medicine'] ?? '');
      if (medicine != null) {
        _tab = AppTab.medicines;
        _visited.add(AppTab.medicines);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKeys[AppTab.medicines]!.currentState?.push(
            MaterialPageRoute<void>(builder: (_) => MedicineDetailsScreen(medicine: medicine)),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    MophMedicineService().datasetRevision.removeListener(_onPricesUpdated);
    ReminderService().pendingDose.removeListener(_onDoseDue);
    super.dispose();
  }

  /// A reminder was tapped or an alarm is due: show the dose screen above
  /// every section.
  void _onDoseDue() {
    final reminders = ReminderService();
    final dose = reminders.pendingDose.value;
    if (dose == null || !mounted) return;
    reminders.pendingDose.value = null;
    unawaited(DoseScreen.show(Navigator.of(context, rootNavigator: true), dose));
  }

  /// A newer MOPH list arrived in the background (see MophMedicineService).
  void _onPricesUpdated() {
    if (!mounted) return;
    final moph = MophMedicineService();
    setState(() {});

    // Price changes for medicines the user takes or has scanned.
    final mine = <String>{
      for (final reminder in ReminderService().reminders)
        if (reminder.medicineId.isNotEmpty) reminder.medicineId,
      for (final record in PrescriptionHistoryService().records)
        for (final entry in record.medicines)
          if (entry.medicineId.isNotEmpty) entry.medicineId,
    };
    final changes = moph.lastPriceChanges.where((c) => mine.contains(c.medicine.medicineId)).toList();

    final updated = appText(_isArabic).medicinePricesUpdatedToTheLatest(moph.publishedDate);

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        duration: Duration(seconds: changes.isEmpty ? 4 : 8),
        content: Text(changes.isEmpty ? updated : '$updated\n${changes.take(3).map(_describeChange).join('\n')}'),
      ),
    );
  }

  String _describeChange(PriceChange change) {
    final arrow = change.newPrice > change.oldPrice ? '↑' : '↓';
    final sign = change.percent > 0 ? '+' : '';
    return '${change.medicine.brandName} ${change.medicine.strength ?? ''}: '
        '${formatCount(change.oldPrice)} → ${formatCount(change.newPrice)} LBP ($arrow $sign${change.percent}%)';
  }

  final Map<AppTab, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>(),
  };

  /// Tabs are built on first visit so, for example, the map does not ask for
  /// location permission until the user opens it.
  final Set<AppTab> _visited = <AppTab>{AppTab.home};

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  static const List<AppTab> _compactTabs = <AppTab>[
    AppTab.home,
    AppTab.medicines,
    AppTab.doctors,
    AppTab.pharmacies,
    AppTab.myHealth,
  ];

  void _select(AppTab tab) {
    final compact = Breakpoints.isCompact(context);

    // Phones have no settings tab; open it on top of the current section.
    if (tab == AppTab.settings && compact) {
      _navigatorKeys[_tab]!.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      return;
    }

    if (tab == _tab) {
      // Tapping the active section returns to its first page.
      _navigatorKeys[tab]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _rootFor(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return const HomeScreen();
      case AppTab.medicines:
        return const MedicineSearchScreen();
      case AppTab.doctors:
        return const DoctorsScreen();
      case AppTab.pharmacies:
        return const PharmaciesMapScreen();
      case AppTab.myHealth:
        return const MyHealthScreen();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }

  void _handleBack() {
    final navigator = _navigatorKeys[_tab]!.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (_tab != AppTab.home) {
      setState(() => _tab = AppTab.home);
      return;
    }
    SystemNavigator.pop();
  }

  String _label(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return appText(_isArabic).home;
      case AppTab.medicines:
        return appText(_isArabic).medicines;
      case AppTab.doctors:
        return appText(_isArabic).doctors;
      case AppTab.pharmacies:
        return appText(_isArabic).pharmacies;
      case AppTab.myHealth:
        return appText(_isArabic).myHealth;
      case AppTab.settings:
        return appText(_isArabic).settings;
    }
  }

  (IconData, IconData) _icons(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return (Icons.home_outlined, Icons.home_rounded);
      case AppTab.medicines:
        return (Icons.medication_outlined, Icons.medication_rounded);
      case AppTab.doctors:
        return (Icons.medical_services_outlined, Icons.medical_services_rounded);
      case AppTab.pharmacies:
        return (Icons.local_pharmacy_outlined, Icons.local_pharmacy_rounded);
      case AppTab.myHealth:
        return (Icons.favorite_outline_rounded, Icons.favorite_rounded);
      case AppTab.settings:
        return (Icons.settings_outlined, Icons.settings_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Breakpoints.medium;
    final expanded = width >= Breakpoints.expanded;

    // Settings is a phone-only push; switching to a phone layout while it is
    // the active tab falls back to home.
    final activeTab = compact && _tab == AppTab.settings ? AppTab.home : _tab;

    final content = Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: AppTab.values.indexOf(activeTab),
            children: [
              for (final tab in AppTab.values)
                _visited.contains(tab)
                    ? HeroControllerScope(
                        controller: MaterialApp.createMaterialHeroController(),
                        child: Navigator(
                          key: _navigatorKeys[tab],
                          onGenerateRoute: (settings) => MaterialPageRoute<void>(
                            settings: settings,
                            builder: (_) => _rootFor(tab),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
        const _OfflineBanner(),
      ],
    );

    Widget body;
    if (compact) {
      body = Scaffold(
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _compactTabs.indexOf(activeTab).clamp(0, _compactTabs.length - 1),
          onDestinationSelected: (index) => _select(_compactTabs[index]),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final tab in _compactTabs)
              NavigationDestination(
                icon: Icon(_icons(tab).$1),
                selectedIcon: Icon(_icons(tab).$2),
                label: _label(tab),
              ),
          ],
        ),
      );
    } else {
      body = Scaffold(
        body: Row(
          children: [
            if (expanded)
              _Sidebar(
                current: activeTab,
                label: _label,
                icons: _icons,
                onSelect: _select,
                isArabic: _isArabic,
              )
            else
              _Rail(
                current: activeTab,
                label: _label,
                icons: _icons,
                onSelect: _select,
              ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return AppShellScope(
      currentTab: activeTab,
      selectTab: _select,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: body,
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.current,
    required this.label,
    required this.icons,
    required this.onSelect,
  });

  final AppTab current;
  final String Function(AppTab) label;
  final (IconData, IconData) Function(AppTab) icons;
  final void Function(AppTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: BorderDirectional(end: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: NavigationRail(
          backgroundColor: Colors.transparent,
          selectedIndex: AppTab.values.indexOf(current),
          onDestinationSelected: (index) => onSelect(AppTab.values[index]),
          labelType: NavigationRailLabelType.all,
          leading: const Padding(
            padding: EdgeInsets.only(bottom: 12, top: 6),
            child: _LogoMark(size: 40),
          ),
          indicatorColor: palette.tealSurface,
          selectedIconTheme: const IconThemeData(color: PharmaLensColors.teal),
          destinations: [
            for (final tab in AppTab.values)
              NavigationRailDestination(
                icon: Icon(icons(tab).$1),
                selectedIcon: Icon(icons(tab).$2),
                label: Text(label(tab)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.label,
    required this.icons,
    required this.onSelect,
    required this.isArabic,
  });

  final AppTab current;
  final String Function(AppTab) label;
  final (IconData, IconData) Function(AppTab) icons;
  final void Function(AppTab) onSelect;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final moph = MophMedicineService();

    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: palette.surface,
        border: BorderDirectional(end: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _LogoMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                            children: const [
                              TextSpan(text: 'Pharma'),
                              TextSpan(text: 'Lens', style: TextStyle(color: PharmaLensColors.teal)),
                            ],
                          ),
                        ),
                        Text(
                          appText(isArabic).medicineSafetyAssistant,
                          style: TextStyle(color: palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              for (final tab in AppTab.values) ...[
                if (tab == AppTab.settings) const Spacer(),
                _SidebarItem(
                  icon: current == tab ? icons(tab).$2 : icons(tab).$1,
                  label: label(tab),
                  selected: current == tab,
                  onTap: () => onSelect(tab),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: moph.isDataStale ? palette.dangerSurface : palette.tealSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      moph.isDataStale ? Icons.history_toggle_off_rounded : Icons.verified_outlined,
                      size: 18,
                      color: moph.isDataStale ? PharmaLensColors.warning : PharmaLensColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appText(isArabic).mophListMedicines(moph.publishedDate, formatCount(moph.totalMedicineCount)),
                        style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
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

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.tealSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 21, color: selected ? PharmaLensColors.teal : palette.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? palette.textPrimary : palette.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: PharmaLensGradients.primary,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: PharmaLensShadows.cyanGlow,
      ),
      child: Icon(Icons.medication_liquid_rounded, color: Colors.white, size: size * 0.58),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService(),
      builder: (context, online, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: online
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    color: PharmaLensColors.warning,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appText(isArabic).youAreOfflineMedicineSearchDoctors,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
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
