import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/alerts/data/alerts_api.dart';
import 'package:stock_adviser/features/alerts/domain/alert.dart';
import 'package:stock_adviser/features/auth/application/auth_controller.dart';
import 'package:stock_adviser/features/auth/data/token_store.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/live/live_connection.dart';
import 'package:stock_adviser/features/live/live_controller.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';
import 'package:stock_adviser/features/notifications/data/notifications_api.dart';
import 'package:stock_adviser/features/notifications/domain/app_notification.dart';

import 'helpers.dart';
import 'market_test.dart' show FakeMarketApi;

class FakeConnection implements LiveConnection {
  final sent = <Map<String, dynamic>>[];
  final _messages = StreamController<Map<String, dynamic>>();

  void push(Map<String, dynamic> message) => _messages.add(message);

  @override
  Future<void> get ready async {}

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  int? get closeCode => null;

  @override
  void send(Map<String, dynamic> message) => sent.add(message);

  @override
  Future<void> close() => _messages.close();
}

class FakeAlertsApi implements AlertsApi {
  final created = <Map<String, Object>>[];

  @override
  Future<List<PriceAlert>> list({int? assetId}) async => [];

  @override
  Future<PriceAlert> create({
    required int assetId,
    required AlertKind kind,
    required double threshold,
    required bool notifyEmail,
  }) async {
    created.add({
      'asset': assetId,
      'kind': kind,
      'threshold': threshold,
      'email': notifyEmail,
    });
    return PriceAlert(
      id: 1,
      asset: testAsset(),
      kind: kind,
      threshold: threshold,
      notifyEmail: notifyEmail,
      isActive: true,
      lastTriggeredAt: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppNotification notification(int id, {bool read = false}) => AppNotification(
  id: id,
  kind: 'alert',
  title: 'BTC is above \$90,000.00',
  body: 'Bitcoin is now \$90,512.00.',
  assetId: 1,
  read: read,
  createdAt: DateTime.utc(2026, 10, 14, 9),
);

void main() {
  test(
    'live controller authenticates, subscribes and applies pushes',
    () async {
      final connection = FakeConnection();
      final tokens = TokenStore(
        FakeSecureStorage(),
        secureStorageAvailable: true,
      )..accessToken = 'access-1';
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.authenticated(testUser())),
          ),
          tokenStoreProvider.overrideWithValue(tokens),
          liveConnectionFactoryProvider.overrideWithValue((_) => connection),
          notificationsProvider.overrideWith(
            () => FakeNotificationsController(
              const NotificationInbox(unreadCount: 0, items: []),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationsProvider.future);

      final live = container.read(liveControllerProvider.notifier);
      live.setInterest('home', [1, 2]);
      live.setInterest('asset:2', [2, 3]);
      await Future<void>.delayed(Duration.zero);
      expect(connection.sent.first, {'type': 'auth', 'token': 'access-1'});

      connection.push({'type': 'ready'});
      await Future<void>.delayed(Duration.zero);
      final subscribe = connection.sent.last;
      expect(subscribe['type'], 'subscribe');
      expect((subscribe['asset_ids'] as List).toSet(), {1, 2, 3});

      connection.push({
        'type': 'quotes',
        'quotes': {
          '2': {
            'price': 90512.0,
            'change': 512.0,
            'change_percent': 0.57,
            'previous_close': 90000.0,
            'currency': 'USD',
            'as_of': '2026-10-14T09:00:00',
            'market_open': true,
          },
        },
      });
      connection.push({
        'type': 'notification',
        'notification': {
          'id': 7,
          'kind': 'alert',
          'title': 'BTC is above \$90,000.00',
          'body': 'Bitcoin is now \$90,512.00.',
          'asset_id': 2,
          'alert_id': 3,
          'data': <String, dynamic>{},
          'read': false,
          'created_at': '2026-10-14T09:00:00',
        },
        'unread_count': 1,
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(liveControllerProvider);
      expect(state.quotes[2]!.price, 90512.0);
      expect(state.lastNotification!.id, 7);
      final inbox = container.read(notificationsProvider).value!;
      expect(inbox.unreadCount, 1);
      expect(inbox.items.single.title, startsWith('BTC is above'));

      live.clearInterest('asset:2');
      expect((connection.sent.last['asset_ids'] as List).toSet(), {1, 2});
    },
  );

  testWidgets('home shows the watchlist and the unread badge', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      AuthState.authenticated(testUser()),
      watchlist: [
        testAsset(id: 5, symbol: 'EMAAR.AE', name: 'Emaar Properties'),
      ],
      inbox: NotificationInbox(
        unreadCount: 2,
        items: [notification(1), notification(2)],
      ),
    );
    expect(find.text('Your watchlist'), findsOneWidget);
    expect(find.text('Emaar Properties'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // badge

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.textContaining('BTC is above'), findsNWidgets(2));
    expect(find.text('Mark all as read'), findsOneWidget);
  });

  testWidgets('empty watchlist explains how to add assets', (tester) async {
    await pumpApp(tester, AuthState.authenticated(testUser()));
    expect(find.textContaining('Tap ☆ on any stock'), findsOneWidget);
  });

  testWidgets('asset page: star toggles, alert form sends the right values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final alerts = FakeAlertsApi();
    await pumpApp(
      tester,
      AuthState.authenticated(testUser()),
      overrides: [
        marketApiProvider.overrideWithValue(FakeMarketApi()),
        alertsApiProvider.overrideWithValue(alerts),
      ],
    );
    GoRouterHelper(tester.element(find.byType(Scaffold).first)).go('/assets/1');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to watchlist'));
    await tester.pumpAndSettle();
    expect(find.text('Added to your watchlist.'), findsOneWidget);
    expect(find.byTooltip('Remove from watchlist'), findsOneWidget);

    await tester.tap(find.text('Create alert'));
    await tester.pumpAndSettle();
    // Prefilled 5% above the current SAR 25.78.
    expect(find.text('Price goes above SAR 27.07'), findsOneWidget);

    await tester.tap(find.text('Falls by % in a day'));
    await tester.pumpAndSettle();
    expect(find.text('Falls 5.00% or more in a day'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '3.5');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create alert'));
    await tester.pumpAndSettle();

    expect(alerts.created.single, {
      'asset': 1,
      'kind': AlertKind.moveDown,
      'threshold': 3.5,
      'email': true,
    });
    expect(find.text("Alert created. We'll let you know."), findsOneWidget);
  });
}
