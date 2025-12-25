import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/channel.dart';
import 'tv_theme.dart';

class TvRailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onActivate;
  final bool selected;

  const TvRailItem({
    required this.icon,
    required this.label,
    this.onActivate,
    this.selected = false,
    super.key,
  });

  @override
  State<TvRailItem> createState() => _TvRailItemState();
}

class _TvRailItemState extends State<TvRailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onActivate != null;
    final Color baseColor = widget.selected ? tvAccent : Colors.white70;
    final Color iconColor = enabled ? baseColor : baseColor.withAlpha(102);
    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        setState(() {
          _focused = value;
        });
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _focused
              ? tvCardFocused
              : Colors.black.withAlpha(widget.selected ? 102 : 38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused
                ? tvAccent.withAlpha(230)
                : Colors.white.withAlpha(widget.selected ? 51 : 20),
            width: _focused ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: GoogleFonts.spaceGrotesk(
                  color:
                      enabled ? Colors.white : Colors.white.withAlpha(128),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvHeroCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final String logoUrl;
  final VoidCallback? onActivate;

  const TvHeroCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.logoUrl,
    this.onActivate,
    super.key,
  });

  @override
  State<TvHeroCard> createState() => _TvHeroCardState();
}

class _TvHeroCardState extends State<TvHeroCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onActivate != null;
    final String logoUrl = widget.logoUrl.trim();
    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        setState(() {
          _focused = value;
        });
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _focused ? 1.02 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [tvCard, tvCardFocused],
            ),
            border: Border.all(
              color: _focused ? tvAccent : Colors.white.withAlpha(20),
              width: _focused ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(89),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(64),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: logoUrl.isEmpty
                    ? Image.asset(
                        'assets/images/tv-icon.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        logoUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/tv-icon.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.spaceGrotesk(
                        color: tvAccentWarm,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: tvTextMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _focused ? tvAccent : Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        enabled ? 'Press OK to Play' : 'No channel selected',
                        style: GoogleFonts.spaceGrotesk(
                          color: enabled ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

class TvInfoPanel extends StatelessWidget {
  final bool isLoading;
  final int channelCount;
  final String? version;
  final String flavor;

  const TvInfoPanel({
    required this.isLoading,
    required this.channelCount,
    required this.version,
    required this.flavor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(71),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isLoading ? tvAccentWarm : tvAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isLoading ? 'Loading' : 'Ready',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$channelCount channels',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            version == null ? 'Version unavailable' : 'v$version • $flavor',
            style: GoogleFonts.spaceGrotesk(
              color: tvTextMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Flavor: $flavor',
            style: GoogleFonts.spaceGrotesk(
              color: tvTextMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class TvChannelCard extends StatefulWidget {
  final Channel channel;
  final int indexLabel;
  final VoidCallback onActivate;

  const TvChannelCard({
    required this.channel,
    required this.indexLabel,
    required this.onActivate,
    super.key,
  });

  @override
  State<TvChannelCard> createState() => _TvChannelCardState();
}

class _TvChannelCardState extends State<TvChannelCard> {
  bool _focused = false;

  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final group = channel.groupTitle.trim();
    final logoUrl = channel.logoUrl.trim();
    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        setState(() {
          _focused = value;
        });
        _handleFocusChange(value);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onActivate();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: _focused ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: _focused ? tvCardFocused : tvCard,
            border: Border.all(
              color: _focused ? tvAccent : Colors.white.withAlpha(20),
              width: _focused ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(_focused ? 102 : 64),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(64),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: logoUrl.isEmpty
                        ? Image.asset(
                            'assets/images/tv-icon.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            logoUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/tv-icon.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _focused
                          ? tvAccentWarm.withAlpha(51)
                          : Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'CH ${widget.indexLabel}',
                      style: GoogleFonts.spaceGrotesk(
                        color: _focused ? tvAccentWarm : tvTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                group.isNotEmpty ? group : 'Live channel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: tvTextMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
