import 'package:flutter/material.dart';
import 'package:nature_biotic/services/sync_manager.dart';

/// A global offline indicator banner that automatically appears
/// when the device loses internet connectivity.
class OfflineAwareBanner extends StatelessWidget {
  final Widget child;
  const OfflineAwareBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncManager().isOnline,
      builder: (context, isOnline, _) {
        return Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                );
              },
              child: isOnline
                  ? const _SyncedBanner(key: ValueKey('online'))
                  : const _OfflineBanner(key: ValueKey('offline')),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFE65100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Offline — Changes saved locally and will sync when reconnected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: SyncManager().pendingCount,
                builder: (context, count, _) {
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncedBanner extends StatelessWidget {
  const _SyncedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SyncManager().pendingCount,
      builder: (context, count, _) {
        // Only show the "synced" banner when there are pending items that just got synced,
        // or show nothing when fully synced and online
        if (count > 0) {
          // Still has pending — show a subtle "syncing" indicator
          return Material(
            elevation: 0,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Syncing $count item${count == 1 ? '' : 's'}...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // All synced — show last synced time briefly
        return ValueListenableBuilder<DateTime?>(
          valueListenable: SyncManager().lastSyncedAt,
          builder: (context, lastSync, _) {
            if (lastSync == null) return const SizedBox.shrink();
            return _LastSyncedLabel(syncTime: lastSync);
          },
        );
      },
    );
  }
}

/// Shows "All synced · X min ago" for 8 seconds then hides itself
class _LastSyncedLabel extends StatefulWidget {
  final DateTime syncTime;
  const _LastSyncedLabel({required this.syncTime});

  @override
  State<_LastSyncedLabel> createState() => _LastSyncedLabelState();
}

class _LastSyncedLabelState extends State<_LastSyncedLabel> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Auto-hide after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didUpdateWidget(_LastSyncedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncTime != widget.syncTime) {
      setState(() => _visible = true);
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(widget.syncTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _visible
          ? Material(
              key: const ValueKey('synced'),
              elevation: 0,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'All synced · ${_timeAgo()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }
}

/// A small floating sync status badge — use in AppBars
class SyncStatusIcon extends StatelessWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncManager().isOnline,
      builder: (context, isOnline, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Icon(
            isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: isOnline ? Colors.green : Colors.orange,
            size: 20,
          ),
        );
      },
    );
  }
}
