import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class CommonTestCases {
  WidgetTester tester;
  CommonTestCases(this.tester);

  Future<void> isSpecificPage<T>() async {
    await tester.pumpAndSettle();
    hasType<T>();
  }

  Future<void> tapItemByKey(
    String key, {
    bool shouldPumpAndSettle = true,
    int pumpDuration = 100,
  }) async {
    final widget = find.byKey(ValueKey(key)).first;
    await tester.tap(widget);
    shouldPumpAndSettle
        ? await tester.pumpAndSettle(Duration(milliseconds: pumpDuration))
        : await tester.pump();
  }

  Future<void> tapItemByFinder(Finder finder, {bool shouldPumpAndSettle = true}) async {
    await tester.tap(finder);
    shouldPumpAndSettle ? await tester.pumpAndSettle() : await tester.pump();
  }

  void hasText(String text, {bool hasWidget = true}) {
    final textWidget = find.text(text);
    expect(textWidget, hasWidget ? findsOneWidget : findsNothing);
  }

  void hasTextAtLestOnce(String text, {bool hasWidget = true}) {
    final textWidget = find.text(text);
    expect(textWidget, hasWidget ? findsAny : findsNothing);
  }

  void hasType<T>() {
    final typeWidget = find.byType(T);
    expect(typeWidget, findsOneWidget);
  }

  bool isKeyPresent(String key) {
    final typeWidget = find.byKey(ValueKey(key));
    return typeWidget.tryEvaluate();
  }

  void hasValueKey(String key) {
    final typeWidget = find.byKey(ValueKey(key));
    expect(typeWidget, findsOneWidget);
  }

  Future<void> swipePage({bool swipeRight = true}) async {
    await tester.drag(find.byType(PageView), Offset(swipeRight ? -300 : 300, 0));
    await tester.pumpAndSettle();
  }

  Future<void> swipeByPageKey({required String key, bool swipeRight = true}) async {
    await tester.drag(find.byKey(ValueKey(key)), Offset(swipeRight ? -300 : 300, 0));
    await tester.pumpAndSettle();
  }

  Future<void> goBack() async {
    tester.printToConsole('Routing back to previous screen');
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
  }

  Future<void> dragUntilVisible(
    String childKey,
    String parentKey, {
    int maxScrolls = 100,
    double scrollStep = 50.0,
    int maxReverseScrolls = 50,
  }) async {
    await tester.pumpAndSettle();

    final itemFinder = find.byKey(ValueKey(childKey));
    final listFinder = find.byKey(ValueKey(parentKey));

    // Check if the widget is already in the widget tree
    if (tester.any(itemFinder)) {
      // Widget is already built and in the tree
      tester.printToConsole('Child is already present');
      return;
    }

    // Find the Scrollable associated with the Parent Ad
    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );

    // Ensure that the Scrollable is found
    expect(
      scrollableFinder,
      findsOneWidget,
      reason: 'Scrollable descendant of the Parent Widget not found.',
    );

    // Get the initial scroll position
    final scrollableState = tester.state<ScrollableState>(scrollableFinder);
    double previousScrollPosition = scrollableState.position.pixels;
    bool scrollDown = true;
    bool reversedDirection = false;
    bool found = false;

    int reverseScrollCount = 0;

    for (int scrolls = 0; scrolls < maxScrolls; scrolls++) {
      await tester.pumpAndSettle();

      // Check if the widget is visible
      if (tester.any(itemFinder)) {
        found = true;
        break;
      }

      // Log current state for debugging
      tester.printToConsole('Scrolling ${scrollDown ? 'down' : 'up'}, attempt $scrolls');

      // Stop if reverse scroll limit is exceeded
      if (!scrollDown && reverseScrollCount >= maxReverseScrolls) {
        tester.printToConsole('Maximum reverse scrolls reached. Widget not found.');
        break;
      }

      // Perform scrolling in the current direction
      await tester.drag(
        scrollableFinder,
        scrollDown ? Offset(0, -scrollStep) : Offset(0, scrollStep),
      );
      await tester.pumpAndSettle();

      // Update the scroll position after the drag
      final currentScrollPosition = scrollableState.position.pixels;

      if (currentScrollPosition == previousScrollPosition) {
        // Cannot scroll further in the current direction
        if (reversedDirection) {
          // We've already tried both directions
          tester.printToConsole('Reached the scroll limit in both directions. Widget not found.');
          break;
        } else {
          // Reverse the scroll direction and reset reverse scroll count
          scrollDown = !scrollDown;
          reversedDirection = true;
          reverseScrollCount = 0;
          tester.printToConsole('Reached the end, reversing direction');
        }
      } else {
        // Update scroll position and reverse scroll count, incrementing only for reverse scrolling
        previousScrollPosition = currentScrollPosition;
        if (!scrollDown) reverseScrollCount++;
      }
    }

    if (!found) {
      tester.printToConsole('Widget not found after $maxScrolls scrolls.');
    }
  }

  Future<void> enterText(String text, String editableTextKey) async {
    final editableTextWidget = find.byKey(ValueKey((editableTextKey)));

    await tester.enterText(editableTextWidget, text);

    await tester.pumpAndSettle();
  }

  void findWidgetViaDescendant({
    required FinderBase<Element> of,
    required FinderBase<Element> matching,
  }) {
    final textWidget = find.descendant(of: of, matching: matching);

    expect(textWidget, findsOneWidget);
  }

  Future<void> defaultSleepTime({int seconds = 2}) async =>
      await Future.delayed(Duration(seconds: seconds));

  Future<void> takeScreenshots(String screenshotName) async {
    await (tester.binding as IntegrationTestWidgetsFlutterBinding).takeScreenshot(screenshotName);
  }
}
