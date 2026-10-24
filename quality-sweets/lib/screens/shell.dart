import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart' as fmt;
import '../store.dart';
import '../theme.dart';
import 'admin/admin_screen.dart';
import 'bill_screen.dart';
import 'home_screen.dart';
import 'saved_bills_screen.dart';

/// Bottom-navigation shell. Each tab keeps its own navigation stack, so
/// browsing a category never loses the current bill.
class Shell extends StatefulWidget {
  const Shell({super.key});

  static const home = 0;
  static const bill = 1;
  static const saved = 2;
  static const admin = 3;

  static final tab = ValueNotifier<int>(home);
  static final _navigators = List.generate(4, (_) => GlobalKey<NavigatorState>());

  /// Switches tab and returns it to its first screen.
  static void go(int index) {
    _navigators[index].currentState?.popUntil((route) => route.isFirst);
    tab.value = index;
  }

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const _roots = <Widget>[HomeScreen(), BillScreen(), SavedBillsScreen(), AdminScreen()];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wide = MediaQuery.sizeOf(context).width >= tabletBreakpoint;
    return ValueListenableBuilder<int>(
      valueListenable: Shell.tab,
      builder: (context, index, _) {
        final stack = IndexedStack(
          index: index,
          children: [
            // Each tab has its own messenger so snackbars sit above that
            // tab's bottom bar instead of covering the bill buttons.
            for (var i = 0; i < _roots.length; i++)
              ScaffoldMessenger(
                child: Navigator(
                  key: Shell._navigators[i],
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _roots[i]),
                ),
              ),
          ],
        );
        final count = store.draft.lines.length;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final navigator = Shell._navigators[index].currentState;
            if (navigator != null && navigator.canPop()) {
              navigator.pop();
            } else if (index != Shell.home) {
              Shell.tab.value = Shell.home;
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            body: wide && index == Shell.home
                ? Row(
                    children: [
                      Expanded(child: stack),
                      const VerticalDivider(width: 1),
                      const SizedBox(width: 400, child: BillScreen(embedded: true)),
                    ],
                  )
                : stack,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (selected) =>
                  selected == index ? Shell.go(selected) : Shell.tab.value = selected,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.receipt_long),
                  ),
                  label: count > 0 ? fmt.money(store.draft.grandTotal) : 'Bill',
                  tooltip: 'Current bill',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Saved',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Admin',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
