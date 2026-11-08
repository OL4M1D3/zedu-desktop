import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);

    // Initialise the cross-DM notification poller so notifications fire
    // even for conversations you haven't opened yet.
    ref.read(dmNotificationPollerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: kIsWeb ? 'Zedu | Team Messaging & Collaboration' : 'Zedu',
      theme: reduceMotion
          ? AppTheme.light.copyWith(pageTransitionsTheme: noPageTransitions)
          : AppTheme.light,
      darkTheme: reduceMotion
          ? AppTheme.dark.copyWith(pageTransitionsTheme: noPageTransitions)
          : AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      builder: (context, child) => ReduceMotionScope(
        reduceMotion: reduceMotion,
        child: AppZoomShortcut(
          child: DesktopWindowTitleListener(
            child: CreditsPaymentDeepLinkListener(
              child: AuthDeepLinkListener(
                child: SessionExpiryListener(
                  child: QuickSwitcherShortcut(
                    child: isDesktopApp
                        // Close-to-tray, the tray menu and desktop notifications.
                        ? DesktopManager(
                            child: child ?? const SizedBox.shrink(),
                          )
                        : child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
