import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The workspace's channels in the home sidebar. Tapping a row opens it.
/// Private channels are listed apart, under a "Private" heading that can be
/// collapsed.
class SidebarChannelList extends ConsumerStatefulWidget {
  const SidebarChannelList({super.key});

  @override
  ConsumerState<SidebarChannelList> createState() => _SidebarChannelListState();
}

class _SidebarChannelListState extends ConsumerState<SidebarChannelList> {
  bool _privateExpanded = true;

  @override
  Widget build(BuildContext context) {
    final channelState = ref.watch(channelProvider);
    final colors = context.colors;
    final orgId = ref.watch(
      workspaceProvider.select((s) => s.selectedWorkspace?.id),
    );
    // Right after a workspace switch, and when the new workspace's load
    // failed, the state still holds the previous workspace's channels. Show
    // only channels of the selected workspace, and none after a failed load.
    // A channel without an organisation id is kept, since we can't tell.
    final channels =
        (channelState.hasError
                ? const <Channel>[]
                : channelState.value ?? const <Channel>[])
            .where(
              (c) =>
                  !c.archived &&
                  (c.organisationId.isEmpty || c.organisationId == orgId),
            )
            .toList();
    final activeChat = ref.watch(activeChatProvider);
    final privateChannels = channels.where((c) => c.isPrivate).toList();

    Widget item(Channel channel) => _SidebarChannelItem(
      label: channel.name,
      isPrivate: channel.isPrivate,
      selected:
          activeChat.type == ActiveChatType.channel &&
          activeChat.id == channel.name,
      onTap: () => ref
          .read(activeChatProvider.notifier)
          .selectChannel(channel.name, channelId: channel.id),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (channelState.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Unable to load channels.',
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: channelState.isLoading
                        ? null
                        : () => ref.read(channelProvider.notifier).retryLoad(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          for (final channel in channels)
            if (!channel.isPrivate) item(channel),
          if (privateChannels.isNotEmpty) ...[
            _PrivateHeading(
              expanded: _privateExpanded,
              onToggle: () =>
                  setState(() => _privateExpanded = !_privateExpanded),
            ),
            if (_privateExpanded) ...privateChannels.map(item),
          ],
        ],
      ),
    );
  }
}

/// The "Private" heading; clicking it collapses or expands the private
/// channels under it.
class _PrivateHeading extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _PrivateHeading({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded ? 'Collapse private channels' : 'Expand private channels',
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                color: colors.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Private',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarChannelItem extends StatelessWidget {
  final String label;
  final bool isPrivate;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarChannelItem({
    required this.label,
    required this.isPrivate,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? colors.onPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (isPrivate)
                  Icon(
                    Icons.lock_outline,
                    semanticLabel: 'Private channel',
                    color: colors.onPrimary.withValues(alpha: 0.54),
                    size: 16,
                  )
                else
                  Text(
                    '#',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.54),
                      fontSize: 18,
                    ),
                  ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
