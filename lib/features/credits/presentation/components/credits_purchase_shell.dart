import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreditsPurchaseShell extends ConsumerWidget {
  const CreditsPurchaseShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final userName = authState.user?.fullname ?? 'Zedu User';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _CreditsTopBar(userName: userName),
            Expanded(
              child: Row(
                children: [
                  AppSidebarRail(
                    activeType: null,
                    onTypeSelected: (type) {
                      ref.read(homeSidebarProvider.notifier).setType(type);
                      context.go(AppRouter.home);
                    },
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsTopBar extends StatelessWidget {
  const _CreditsTopBar({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: context.colors.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset(
            'assets/pngs/zedu_logo.png',
            width: 82,
            height: 31,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 24),
          TopUserMenu(
            userName: userName,
            backgroundColor: context.colors.primary.withValues(alpha: 0.58),
          ),
          const Spacer(),
          const Flexible(child: TopBarSearchBox(maxWidth: 360)),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
