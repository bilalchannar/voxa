// Widget tests for Voxa.
//
// The previous template test pumped the entire app and checked a counter that
// never existed. Pumping `MyApp` now requires Firebase to be initialised (the
// auth screen touches `FirebaseAuth.instance`), which isn't available in a
// plain widget test. Instead we test a pure, Firebase-free widget so the suite
// stays fast and meaningful.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voxa/widgets/profile/profile_avatar.dart';

void main() {
  testWidgets('ProfileAvatar shows the initial when there is no photo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(photoUrl: null, initial: 'A'),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('ProfileAvatar still shows the initial for an empty photo url',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(photoUrl: '', initial: 'V'),
        ),
      ),
    );

    expect(find.text('V'), findsOneWidget);
  });
}
