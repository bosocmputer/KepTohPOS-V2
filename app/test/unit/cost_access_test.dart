import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StaffMember staff(String role, {bool canViewCosts = false}) => StaffMember(
    id: 's',
    name: 'n',
    role: role,
    pin: '',
    canViewCosts: canViewCosts,
  );

  group('StaffMember.seesCosts', () {
    test('owners always, managers only when allowed, cashiers never', () {
      expect(staff('owner').seesCosts, isTrue);
      expect(staff('manager').seesCosts, isFalse);
      expect(staff('manager', canViewCosts: true).seesCosts, isTrue);
      expect(staff('cashier', canViewCosts: true).seesCosts, isFalse);
    });

    test('the permission survives a JSON round trip; old data means off', () {
      final allowed = staff('manager', canViewCosts: true);
      expect(StaffMember.fromJson(allowed.toJson()).canViewCosts, isTrue);
      final legacy = allowed.toJson()..remove('canViewCosts');
      expect(StaffMember.fromJson(legacy).canViewCosts, isFalse);
    });
  });

  group('views for a manager', () {
    List<String> ids(List<AppViewSpec> views) =>
        views.map((v) => v.id).toList();

    test('without the permission, profit and reports are hidden', () {
      // Act
      final views = ids(allowedViewsFor('manager', seesCosts: false));

      // Assert
      expect(views, isNot(contains('dashboard')));
      expect(views, isNot(contains('reports')));
      expect(views, containsAll(<String>['tables', 'bills', 'stock', 'setup']));
      expect(
        canAccessViewIdFor('manager', 'reports/daily', seesCosts: false),
        isFalse,
      );
    });

    test('with the permission, the views match the role', () {
      expect(
        ids(allowedViewsFor('manager', seesCosts: true)),
        ids(allowedViewsForRole('manager')),
      );
      expect(
        canAccessViewIdFor('manager', 'dashboard', seesCosts: true),
        isTrue,
      );
    });
  });
}
