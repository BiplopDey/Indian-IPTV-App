import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/channel.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

class TvHomeLayout extends StatelessWidget {
  final List<Channel> channels;
  final bool isLoading;
  final String? version;
  final String flavor;
  final VoidCallback? onAddChannel;
  final VoidCallback? onManageChannels;
  final VoidCallback? onRefresh;
  final ValueChanged<int> onChannelSelected;
  final ScrollController scrollController;

  const TvHomeLayout({
    required this.channels,
    required this.isLoading,
    required this.version,
    required this.flavor,
    required this.onChannelSelected,
    required this.scrollController,
    this.onAddChannel,
    this.onManageChannels,
    this.onRefresh,
    super.key,
  });

  int _resolveTvColumns(double width) {
    if (width >= 1700) {
      return 6;
    }
    if (width >= 1400) {
      return 5;
    }
    if (width >= 1100) {
      return 4;
    }
    return 3;
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tvBgTop, tvBgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -140,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tvAccent.withAlpha(89),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tvAccentWarm.withAlpha(89),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail(BuildContext context) {
    final VoidCallback? addHandler = isLoading ? null : onAddChannel;
    final VoidCallback? manageHandler = isLoading ? null : onManageChannels;
    final VoidCallback? refreshHandler = isLoading ? null : onRefresh;
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(64),
        border: Border(
          right: BorderSide(
            color: Colors.white.withAlpha(15),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/tv-icon.png',
                width: 36,
                height: 36,
              ),
              const SizedBox(width: 12),
              Text(
                'Live TV',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TvRailItem(
            icon: Icons.add_circle_outline,
            label: 'Add Channels',
            onActivate: addHandler,
          ),
          const SizedBox(height: 12),
          TvRailItem(
            icon: Icons.tune,
            label: 'Manage Channels',
            onActivate: manageHandler,
          ),
          const SizedBox(height: 12),
          TvRailItem(
            icon: Icons.refresh,
            label: 'Refresh List',
            onActivate: refreshHandler,
          ),
          const Spacer(),
          Text(
            'Use CH+ / CH- in player',
            style: GoogleFonts.spaceGrotesk(
              color: tvTextMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            version == null ? 'Flavor: $flavor' : 'v$version • $flavor',
            style: GoogleFonts.spaceGrotesk(
              color: tvTextMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final Channel? channel = channels.isEmpty ? null : channels.first;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Row(
        children: [
          Expanded(
            child: TvHeroCard(
              title: 'Live Now',
              subtitle: channel?.name ?? 'No channel selected',
              description: channel?.groupTitle.isNotEmpty == true
                  ? channel!.groupTitle
                  : 'Pick a channel and start watching instantly',
              logoUrl: channel?.logoUrl ?? '',
              onActivate: channel == null ? null : () => onChannelSelected(0),
            ),
          ),
          const SizedBox(width: 20),
          TvInfoPanel(
            isLoading: isLoading,
            channelCount: channels.length,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels available',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white70,
            fontSize: 20,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _resolveTvColumns(constraints.maxWidth);
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(right: 16, bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 1.45,
          ),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return TvChannelCard(
              channel: channel,
              indexLabel: index + 1,
              onActivate: () => onChannelSelected(index),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && channels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            _buildBackground(),
            const Center(
              child: TvLoadingCard(
                title: 'Loading channels...',
                subtitle: 'Preparing your live TV experience',
              ),
            ),
          ],
        ),
      );
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRail(context),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 8, 0),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildHero(),
                            const SizedBox(height: 24),
                            Text(
                              'All Channels',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildGrid(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
