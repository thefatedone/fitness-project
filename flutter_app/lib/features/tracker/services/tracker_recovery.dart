part of '../providers/tracker_provider.dart';

extension TrackerRecovery on TrackerProvider {
  /// Called by the auth proxy. Recovery from another account or API host never
  /// enters this account's diary, and in-flight responses cannot repopulate it.
  void bindAccount(String? userId, {required String environment}) {
    final key = userId == null ? null : '$environment:$userId';
    if (_recoveryKey == key) {
      return;
    }
    _recoveryGeneration++;
    _dailyLoadGeneration++;
    _recoveryBusy = false;
    isLoading = false;
    gardenLoading = false;
    _recoveryKey = key;
    _undoTimer?.cancel();
    _recovery = userId == null
        ? null
        : DiaryRecoveryStore(userId: userId, environment: environment);
    saveCoordinator.bind(_recovery);
    _recoveryReady = null;
    pendingDeletion = null;
    mealDraft = null;
    recoveryFailed = false;
    dailyDataStale = false;
    foodLogs = [];
    waterLogs = [];
    weightHistory = [];
    garden = null;
    _streak = null;
    if (_recovery != null) {
      unawaited(_ensureRecoveryLoaded().catchError((Object _) {}));
    }
  }

  Future<void> _ensureRecoveryLoaded() => _recoveryReady ??= _loadRecovery();

  Future<void> _loadRecovery() async {
    final store = _recovery;
    final generation = _recoveryGeneration;
    if (store == null) {
      return;
    }
    try {
      final deletion = await store.read('deletion');
      final draft = await store.read('meal-draft');
      if (generation != _recoveryGeneration) {
        return;
      }
      pendingDeletion = deletion == null
          ? null
          : PendingDiaryDeletion.fromJson(deletion);
      mealDraft = draft == null ? null : SavedMealModel.fromJson(draft);
      if (pendingDeletion != null) {
        _overlayPendingDeletion();
        _scheduleUndoExpiry();
      }
    } catch (_) {
      if (generation == _recoveryGeneration) {
        recoveryFailed = true;
        _recoveryReady = null;
      }
      rethrow;
    } finally {
      if (generation == _recoveryGeneration) {
        _notifyRecovery();
      }
    }
  }

  Future<void> persistMealDraft(SavedMealModel draft) async {
    final generation = _recoveryGeneration;
    await _ensureRecoveryLoaded();
    if (generation != _recoveryGeneration) {
      throw StateError('Account changed');
    }
    final store = _recovery;
    if (mealDraft != null && mealDraft!.id != draft.id) {
      throw UnresolvedMealDraft();
    }
    if (store != null) await store.write('meal-draft', draft.toJson());
    if (generation != _recoveryGeneration) {
      throw StateError('Account changed');
    }
    mealDraft = draft;
    _notifyRecovery();
  }

  Future<void> acceptCommittedMeal(List<FoodLogModel> entries) async {
    final store = _recovery;
    final generation = _recoveryGeneration;
    if (store != null) {
      for (final day
          in entries.map((v) => TrackerProvider._formatYmd(v.date)).toSet()) {
        final cached = await store.read('day:$day');
        final current = day == TrackerProvider._formatYmd(selectedDate);
        final foods = current
            ? {for (final v in foodLogs) v.id: v.toCacheJson()}
            : {
                for (final v in (cached?['foods'] as List? ?? []))
                  (v as Map)['id'] as String: Map<String, dynamic>.from(v),
              };
        for (final food in entries.where(
          (v) => TrackerProvider._formatYmd(v.date) == day,
        )) {
          foods[food.id] = food.toCacheJson();
        }
        await store.write('day:$day', {
          'foods': foods.values.toList(),
          'water': current
              ? waterLogs.map((v) => v.toCacheJson()).toList()
              : (cached?['water'] ?? []),
        });
      }
    }
    if (generation != _recoveryGeneration) throw StateError('Account changed');
    addLocalMealEntries(entries);
  }

  Future<void> clearMealDraft(String id) async {
    if (mealDraft?.id != id) {
      return;
    }
    final generation = _recoveryGeneration;
    await _recovery?.remove('meal-draft');
    if (generation != _recoveryGeneration) {
      return;
    }
    mealDraft = null;
    _notifyRecovery();
  }

  Future<void> _cacheCurrentDay() async {
    final store = _recovery;
    if (store == null) {
      return;
    }
    await store.write('day:${TrackerProvider._formatYmd(selectedDate)}', {
      'foods': foodLogs.map((v) => v.toCacheJson()).toList(),
      'water': waterLogs.map((v) => v.toCacheJson()).toList(),
    });
  }

  void _cacheAfterChange({bool changed = true}) {
    if (changed) {
      _diaryRevision++;
    }
    unawaited(_cacheCurrentDay().catchError((Object _) {}));
  }

  void _overlayPendingDeletion() {
    final deletion = pendingDeletion;
    if (deletion == null) {
      return;
    }
    final foodIds = deletion.foods.map((v) => v.id).toSet();
    final waterIds = deletion.water.map((v) => v.id).toSet();
    if (deletion.confirmed && !deletion.restore) {
      foodLogs = foodLogs.where((v) => !foodIds.contains(v.id)).toList();
      waterLogs = waterLogs.where((v) => !waterIds.contains(v.id)).toList();
    } else {
      // An uncertain deletion stays visible. An offline undo stays visible too,
      // even if a GET still reports the earlier deletion from the server.
      final foods = {for (final v in foodLogs) v.id: v};
      final water = {for (final v in waterLogs) v.id: v};
      for (final v in deletion.foods) {
        if (TrackerProvider._midnightOf(v.date) == selectedDate) {
          foods[v.id] = v;
        }
      }
      for (final v in deletion.water) {
        if (TrackerProvider._midnightOf(v.date) == selectedDate) {
          water[v.id] = v;
        }
      }
      foodLogs = foods.values.toList();
      waterLogs = water.values.toList();
    }
  }

  Future<void> _cacheDeletionDays(
    PendingDiaryDeletion deletion, {
    required bool restored,
  }) async {
    final store = _recovery;
    if (store == null) {
      return;
    }
    final dates = {
      ...deletion.foods.map((v) => TrackerProvider._formatYmd(v.date)),
      ...deletion.water.map((v) => TrackerProvider._formatYmd(v.date)),
    };
    for (final day in dates) {
      final cached = await store.read('day:$day');
      final foods = {
        for (final v in (cached?['foods'] as List? ?? []))
          (v as Map)['id'] as String: Map<String, dynamic>.from(v),
      };
      final water = {
        for (final v in (cached?['water'] as List? ?? []))
          (v as Map)['id'] as String: Map<String, dynamic>.from(v),
      };
      for (final food in deletion.foods.where(
        (v) => TrackerProvider._formatYmd(v.date) == day,
      )) {
        if (restored) {
          foods[food.id] = food.toCacheJson();
        } else {
          foods.remove(food.id);
        }
      }
      for (final entry in deletion.water.where(
        (v) => TrackerProvider._formatYmd(v.date) == day,
      )) {
        if (restored) {
          water[entry.id] = entry.toCacheJson();
        } else {
          water.remove(entry.id);
        }
      }
      await store.write('day:$day', {
        'foods': foods.values.toList(),
        'water': water.values.toList(),
      });
    }
  }

  void _scheduleUndoExpiry() {
    _undoTimer?.cancel();
    final deletion = pendingDeletion;
    if (deletion == null || !deletion.confirmed || deletion.restore) {
      return;
    }
    final remaining = deletion.undoUntil.difference(DateTime.now());
    _undoTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () async {
        if (pendingDeletion?.id != deletion.id ||
            pendingDeletion!.restore ||
            _recoveryBusy) {
          return;
        }
        final generation = _recoveryGeneration;
        _recoveryBusy = true;
        try {
          await _cacheDeletionDays(deletion, restored: false);
          await _recovery?.remove('deletion');
          if (generation != _recoveryGeneration) {
            return;
          }
          pendingDeletion = null;
        } catch (_) {
          // Keep the receipt when durable cache reconciliation fails.
        } finally {
          if (generation == _recoveryGeneration) {
            _recoveryBusy = false;
            _notifyRecovery();
          }
        }
      },
    );
  }

  Future<bool> _deleteWithRecovery({
    List<FoodLogModel> foods = const [],
    List<WaterLogModel> water = const [],
  }) async {
    if (_recoveryBusy || isLoading || (foods.isEmpty && water.isEmpty)) {
      return false;
    }
    final generation = _recoveryGeneration;
    final store = _recovery;
    _recoveryBusy = true;
    isLoading = true;
    _notifyRecovery();
    try {
      await _ensureRecoveryLoaded();
      if (generation != _recoveryGeneration) {
        return false;
      }
      if (pendingDeletion != null &&
          (!pendingDeletion!.confirmed || pendingDeletion!.restore)) {
        return false;
      }
      if (pendingDeletion != null) {
        await _cacheDeletionDays(pendingDeletion!, restored: false);
      }
      final deletion = PendingDiaryDeletion(
        id: newMealId(),
        foods: List.of(foods),
        water: List.of(water),
        undoUntil: DateTime.now().add(undoWindow),
      );
      await store?.write('deletion', deletion.toJson());
      if (generation != _recoveryGeneration) {
        return false;
      }
      _undoTimer?.cancel();
      pendingDeletion = deletion;
      _recoveryBusy = false;
      isLoading = false;
      return await retryPendingDeletion();
    } catch (_) {
      if (generation == _recoveryGeneration) {
        recoveryFailed = true;
      }
      return false;
    } finally {
      if (generation == _recoveryGeneration) {
        _recoveryBusy = false;
        isLoading = false;
        _notifyRecovery();
      }
    }
  }

  Future<bool> retryPendingDeletion() async {
    if (_recoveryBusy || pendingDeletion == null) {
      return false;
    }
    final generation = _recoveryGeneration;
    final deletion = pendingDeletion!;
    final store = _recovery;
    _recoveryBusy = true;
    isLoading = true;
    _notifyRecovery();
    try {
      final state = await _trackerApi.changeDeletion(deletion);
      if (generation != _recoveryGeneration) {
        return false;
      }
      if (state == 'restored') {
        await _cacheDeletionDays(deletion, restored: true);
        await store?.remove('deletion');
        if (generation != _recoveryGeneration) {
          return false;
        }
        pendingDeletion = null;
        // Keep the exact originals; response loss must never create new IDs.
        pendingDeletion = deletion.copyWith(restore: true);
        _overlayPendingDeletion();
        pendingDeletion = null;
      } else {
        final confirmed = deletion.copyWith(
          confirmed: true,
          undoUntil: DateTime.now().add(undoWindow),
        );
        await store?.write('deletion', confirmed.toJson());
        if (generation != _recoveryGeneration) {
          return false;
        }
        pendingDeletion = confirmed;
        _overlayPendingDeletion();
        _scheduleUndoExpiry();
      }
      recoveryFailed = false;
      _cacheAfterChange();
      unawaited(refreshStreakAfterSave());
      return true;
    } catch (_) {
      if (generation == _recoveryGeneration) {
        recoveryFailed = true;
        _overlayPendingDeletion();
      }
      return false;
    } finally {
      if (generation == _recoveryGeneration) {
        _recoveryBusy = false;
        isLoading = false;
        _scheduleUndoExpiry();
        _notifyRecovery();
      }
    }
  }

  Future<bool> undoDeletion() async {
    if (_recoveryBusy || pendingDeletion == null) {
      return false;
    }
    final generation = _recoveryGeneration;
    _recoveryBusy = true;
    isLoading = true;
    _notifyRecovery();
    try {
      final restore = pendingDeletion!.copyWith(
        restore: true,
        confirmed: false,
      );
      await _recovery?.write('deletion', restore.toJson());
      if (generation != _recoveryGeneration) {
        return false;
      }
      _undoTimer?.cancel();
      pendingDeletion = restore;
      _overlayPendingDeletion();
      _cacheAfterChange();
      _recoveryBusy = false;
      isLoading = false;
      return await retryPendingDeletion();
    } catch (_) {
      if (generation == _recoveryGeneration) {
        recoveryFailed = true;
      }
      return false;
    } finally {
      if (generation == _recoveryGeneration) {
        _recoveryBusy = false;
        isLoading = false;
        _scheduleUndoExpiry();
        _notifyRecovery();
      }
    }
  }
}
