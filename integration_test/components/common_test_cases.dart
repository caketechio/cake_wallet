import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final widget = find.byKey(ValueKey(key));
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

  Future<void> dragUntilVisible(String childKey, String parentKey) async {
    await tester.pumpAndSettle();

    final itemFinder = find.byKey(ValueKey(childKey));
    final listFinder = find.byKey(ValueKey(parentKey));

    // Check if the widget is already in the widget tree
    if (tester.any(itemFinder)) {
      // Widget is already built and in the tree
      tester.printToConsole('Child is already present');
      return;
    }

    // We can adjust this as needed
    final maxScrolls = 200;

    int scrolls = 0;
    bool found = false;

    // We start by scrolling down
    bool scrollDown = true;

    // Flag to check if we've already reversed direction
    bool reversedDirection = false;

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

    while (!found && scrolls < maxScrolls) {
      tester.printToConsole('Scrolling ${scrollDown ? 'down' : 'up'}, attempt $scrolls');

      // Perform the drag in the current direction
      await tester.drag(
        scrollableFinder,
        scrollDown ? const Offset(0, -100) : const Offset(0, 100),
      );
      await tester.pumpAndSettle();
      scrolls++;

      // Update the scroll position after the drag
      final currentScrollPosition = scrollableState.position.pixels;

      if (currentScrollPosition == previousScrollPosition) {
        // Cannot scroll further in this direction
        if (reversedDirection) {
          // We've already tried both directions
          tester.printToConsole('Cannot scroll further in both directions. Widget not found.');
          break;
        } else {
          // Reverse the scroll direction
          scrollDown = !scrollDown;
          reversedDirection = true;
          tester.printToConsole('Reached the end, reversing direction');
        }
      } else {
        // Continue scrolling in the current direction
        previousScrollPosition = currentScrollPosition;
      }

      // Check if the widget is now in the widget tree
      found = tester.any(itemFinder);
    }

    if (!found) {
      tester.printToConsole('Widget not found after scrolling in both directions.');
      return;
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
}
