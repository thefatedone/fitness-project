import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../services/save_coordinator.dart';

class SaveRecoveryNotice extends StatelessWidget {
  final Future<void> Function(PendingSave)? onResolve;
  final SaveCoordinator? coordinator;
  const SaveRecoveryNotice({super.key, this.onResolve, this.coordinator});
  @override
  Widget build(BuildContext context) {
    final saves = coordinator ?? saveCoordinator;
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: saves,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final save in saves.pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.savePendingTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        save.payload['food_name'] as String? ??
                            save.payload['beverage_name'] as String? ??
                            switch (save.route) {
                              '/tracker/water' =>
                                '${save.payload['amount']} ${l.addFoodUnitMl}',
                              '/tracker/weight' =>
                                '${l.weightHistoryTitle}: ${save.payload['weight']}',
                              _ => l.mealPhotoScan,
                            },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onResolve == null
                              ? null
                              : () => onResolve!(save),
                          child: Text(l.saveCheck),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
