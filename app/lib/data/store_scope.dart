import 'package:flutter/widgets.dart';

import 'store.dart';

/// Makes the [AppStore] available to every screen. `context.store` listens; `context.storeRead` doesn't.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreContext on BuildContext {
  AppStore get store => StoreScope.of(this);
  AppStore get storeRead => StoreScope.read(this);
}
