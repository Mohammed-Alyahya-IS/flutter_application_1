import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';

Future<void> pumpApp(WidgetTester tester, {bool loggedIn = false}) async {
  SharedPreferences.setMockInitialValues({'estirahah_is_logged_in': loggedIn});
  await tester.pumpWidget(const EstirahahApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('auth screen shows login and register fields', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.byKey(const ValueKey('email_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('password_field')), findsOneWidget);
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(find.text('إنشاء حساب'), findsOneWidget);
    expect(find.byKey(const ValueKey('name_field')), findsOneWidget);
  });

  testWidgets('Arabic text input works while the app layout stays LTR', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.ltr,
    );
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('name_field')),
    );
    expect(nameField.textDirection, TextDirection.rtl);
    expect(nameField.textAlign, TextAlign.right);
    await tester.enterText(find.byKey(const ValueKey('name_field')), 'أحمد');

    expect(find.text('أحمد'), findsOneWidget);
  });

  testWidgets('group expense dashboard shows main sections', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, loggedIn: true);

    expect(find.text('إدارة المصاريف المشتركة'), findsOneWidget);
    expect(find.text('المصاريف قطة، والحساب بالملّي'), findsOneWidget);
    expect(find.text('استراحة الشباب'), findsWidgets);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('can add a new group with member chips', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, loggedIn: true);

    await tester.tap(find.byIcon(Icons.group_add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group_name_field')),
      'رحلة العائلة',
    );
    await tester.enterText(
      find.byKey(const ValueKey('member_name_field')),
      'خالد',
    );
    await tester.tap(find.byKey(const ValueKey('add_member_button')));
    await tester.pump();

    expect(find.text('خالد'), findsWidgets);

    await tester.tap(find.text('إنشاء مجموعة'));
    await tester.pumpAndSettle();

    expect(find.text('رحلة العائلة'), findsWidgets);
  });

  testWidgets(
    'group-specific wallet shows current user balance and recharge action',
    (WidgetTester tester) async {
      await pumpApp(tester, loggedIn: true);

      expect(find.textContaining('رصيدي في هذه المجموعة'), findsOneWidget);
      expect(find.text('شحن محفظتي في هذه المجموعة'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_rounded), findsNothing);
    },
  );

  testWidgets('member details show that member expenses', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, loggedIn: true);

    final memberText = find.text('إبراهيم').last;
    await tester.ensureVisible(memberText);
    await tester.pumpAndSettle();
    await tester.tap(memberText);
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل العضو'), findsOneWidget);
    expect(find.text('عشاء الجمعة'), findsWidgets);
  });

  testWidgets('header shows the new tagline and wallet transfer dialog', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, loggedIn: true);

    expect(find.text('المصاريف قطة، والحساب بالملّي'), findsOneWidget);

    await tester.tap(find.text('تحويل رصيد بين المحافظ'));
    await tester.pumpAndSettle();

    expect(find.text('تحويل رصيد بين المحافظ'), findsWidgets);
    expect(find.text('المحفظة المصدر'), findsOneWidget);
    expect(find.text('المحفظة الهدف'), findsOneWidget);
  });

  testWidgets('can add a new member to the current group', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, loggedIn: true);

    final addMemberButton = find.byTooltip('إضافة عضو جديد');
    await tester.ensureVisible(addMemberButton);
    await tester.pumpAndSettle();
    await tester.tap(addMemberButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('new_member_name_field')),
      'سليم',
    );
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(find.text('سليم'), findsWidgets);
  });

  testWidgets('can remove a member from the current group', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, loggedIn: true);

    final deleteButton = find.byTooltip('إزالة العضو').first;
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(find.text('إبراهيم'), findsNothing);
  });

  testWidgets(
    'wallet balances show actual wallet and ledger amounts separately',
    (WidgetTester tester) async {
      await pumpApp(tester, loggedIn: true);

      expect(find.text('رصيدي في هذه المجموعة: 120.00 ر.س'), findsOneWidget);
      expect(find.textContaining('الرصيد المتاح: 120.00 ر.س'), findsWidgets);
      expect(find.textContaining('المستحقات (تطلبهم):'), findsWidgets);
      expect(find.textContaining('الديون (يطلبونك):'), findsWidgets);
    },
  );
}
