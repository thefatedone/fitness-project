import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../providers/tracker_provider.dart';
import '../services/save_coordinator.dart';
import 'save_recovery_notice.dart';

class DiaryRecoveryBanner extends StatelessWidget {
  final TrackerProvider tracker;
  final VoidCallback onResumeMeal;
  final Future<void> Function(PendingSave)? onResolveSave;
  const DiaryRecoveryBanner({
    super.key,
    required this.tracker,
    required this.onResumeMeal,
    this.onResolveSave,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pending = tracker.pendingDeletion;
    Widget notice(String message, List<Widget> actions) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaveRecoveryNotice(onResolve: onResolveSave),
        if (tracker.dailyDataStale)
          notice(l.diaryOfflineCache, [
            TextButton(
              onPressed: tracker.isLoading
                  ? null
                  : () => tracker.loadDailyData(tracker.selectedDate),
              child: Text(l.mealRetry),
            ),
          ]),
        if (pending != null)
          notice(
            pending.restore
                ? l.diaryRestorePending
                : pending.confirmed
                ? l.diaryDeleted
                : l.diaryDeleteUnconfirmed,
            [
              if (!pending.restore)
                TextButton(
                  onPressed: tracker.isLoading ? null : tracker.undoDeletion,
                  child: Text(l.diaryUndo),
                ),
              if (!pending.confirmed)
                TextButton(
                  onPressed: tracker.isLoading
                      ? null
                      : tracker.retryPendingDeletion,
                  child: Text(l.mealRetry),
                ),
            ],
          ),
        if (tracker.recoveryFailed && pending == null)
          notice(l.diaryLocalSaveError, []),
        if (tracker.mealDraft != null)
          notice(l.diaryMealDraft, [
            TextButton(
              onPressed: tracker.isLoading ? null : onResumeMeal,
              child: Text(l.diaryResumeMeal),
            ),
          ]),
      ],
    );
  }
}
