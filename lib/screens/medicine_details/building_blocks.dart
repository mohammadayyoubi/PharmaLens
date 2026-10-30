
// Small shared pieces used by the details cards.
part of '../medicine_details_screen.dart';

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(
                icon: icon,
                color: color,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ExpandableCard extends StatelessWidget {
  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
    this.initiallyExpanded = false,
    this.storageId,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;

  /// Remembers whether the user opened or closed the card. The phone layout
  /// is a lazy list that rebuilds a card each time it scrolls back into
  /// view; without this a closed card opened again by itself.
  final String? storageId;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final isDark =
    PharmaLensTheme.isDark(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
        boxShadow: palette.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        // The tile paints its ink on the nearest Material; without this one
        // the card's colored box would hide it.
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          key: PageStorageKey<String>('details-card-${storageId ?? icon.codePoint}'),
          initiallyExpanded: initiallyExpanded,
          tilePadding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          childrenPadding:
          const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            14,
          ),
          leading: _SectionIcon(
            icon: icon,
            color: color,
            isDark: isDark,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          iconColor: color,
          collapsedIconColor:
          palette.textMuted,
          children: [
            Divider(
              height: 1,
              color: palette.border,
            ),
            const SizedBox(height: 12),
            child,
          ],
          ),
        ),
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? 0.15 : 0.075,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 21,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (!_usable(value)) {
      return const SizedBox.shrink();
    }

    final palette =
    PharmaLensTheme.paletteOf(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 11.2,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textDirection:
                  _textDirectionFor(value),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12.4,
                    height: 1.4,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: palette.border,
          ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textDirection:
          _textDirectionFor(text),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final List<String> values;
  final Color color;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    final cleanedValues = values
        .map((value) => value.trim())
        .where(_usable)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...cleanedValues.map(
              (value) => Padding(
            padding: const EdgeInsets.only(
              bottom: 7,
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                  const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    value,
                    textDirection:
                    _textDirectionFor(value),
                    style: TextStyle(
                      color:
                      palette.textSecondary,
                      fontSize: 12.3,
                      height: 1.45,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrescriptionBox extends StatelessWidget {
  const _PrescriptionBox({
    required this.value,
    required this.isArabic,
  });

  final String value;
  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    const color = PharmaLensColors.accentPurple;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: PharmaLensTheme.isDark(context)
              ? 0.15
              : 0.07,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  appText(isArabic).asWrittenByYourDoctor,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            textDirection:
            _textDirectionFor(value),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewedText extends StatelessWidget {
  const _ReviewedText({
    required this.value,
    required this.hadError,
    required this.isArabic,
    required this.emptyEn,
    required this.emptyAr,
  });

  final String value;
  final bool hadError;
  final bool isArabic;
  final String emptyEn;
  final String emptyAr;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (value.trim().isNotEmpty) {
      return Text(
        value,
        textDirection:
        _textDirectionFor(value),
        style: TextStyle(
          color: PharmaLensTheme.paletteOf(
            context,
          ).textSecondary,
          fontSize: 12.5,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return _MessageBox(
      text: hadError
          ? appText(isArabic).thisInformationCouldNotBeLoaded
          : (isArabic ? emptyAr : emptyEn),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.text,
    this.warning = false,
  });

  final String text;
  final bool warning;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: warning
            ? PharmaLensColors.warning.withValues(
          alpha:
          PharmaLensTheme.isDark(context)
              ? 0.13
              : 0.06,
        )
            : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textDirection:
        _textDirectionFor(text),
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: PharmaLensTheme.isDark(context)
              ? 0.14
              : 0.07,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection:
              _textDirectionFor(label),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.border,
            ),
          ),
          child: loading
              ? Padding(
            padding: const EdgeInsets.all(12),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.textPrimary,
            ),
          )
              : Icon(
            icon,
            color: palette.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.isArabic,
  });

  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appText(isArabic).loadingMedicineInformationAndAlternatives,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyFooter extends StatelessWidget {
  const _SafetyFooter({
    required this.isArabic,
  });

  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PharmaLensColors.warning.withValues(
          alpha: PharmaLensTheme.isDark(context)
              ? 0.13
              : 0.06,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: PharmaLensColors.warning,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              appText(isArabic).doNotChangeTheDoseProduct,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.3,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
