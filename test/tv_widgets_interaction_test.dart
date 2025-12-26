import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/screens/home/tv/tv_widgets.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('TvRailItem triggers onActivate on tap',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvRailItem(
            icon: Icons.add,
            label: 'Add Channels',
            onActivate: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Channels'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('TvChannelCard triggers onActivate on tap',
      (WidgetTester tester) async {
    var activated = false;
    final channel = Channel(
      name: 'Alpha TV',
      logoUrl: '',
      streamUrl: 'http://example.com/alpha.m3u8',
      groupTitle: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvChannelCard(
            channel: channel,
            indexLabel: 1,
            onActivate: () => activated = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Alpha TV'));
    await tester.pump();

    expect(activated, isTrue);
  });
}
