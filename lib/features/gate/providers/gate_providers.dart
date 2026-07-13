import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/gate_models.dart';
import '../data/repositories/gate_repository.dart';

final gateRepositoryProvider = Provider<GateRepository>((ref) {
  return GateRepository(ref.watch(supabaseClientProvider));
});

final gateDriversProvider = FutureProvider<List<GateDriver>>((ref) {
  return ref.watch(gateRepositoryProvider).fetchDrivers();
});

final gateLedgersProvider = FutureProvider<List<GateLedger>>((ref) {
  return ref.watch(gateRepositoryProvider).fetchLedgers();
});

final gateLedgerEntriesProvider =
    FutureProvider.family<List<GateLedgerEntry>, String>((ref, ledgerId) {
      return ref.watch(gateRepositoryProvider).fetchLedgerEntries(ledgerId);
    });

final gateIncomingListsProvider = FutureProvider<List<GateIncoming>>((ref) {
  return ref.watch(gateRepositoryProvider).fetchIncomingLists();
});

final gateIncomingEntriesProvider =
    FutureProvider.family<List<GateIncomingEntry>, String>((ref, incomingId) {
      return ref.watch(gateRepositoryProvider).fetchIncomingEntries(incomingId);
    });
