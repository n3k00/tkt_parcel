import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/tracking_id_service.dart';
import '../../../../data/models/parcel.dart';
import '../../../../data/repositories/parcel_repository.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../shared/models/app_setup_config.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/data/models/staff_profile.dart';
import '../models/voucher_preview_args.dart';

final trackingIdServiceProvider = Provider<TrackingIdService>((ref) {
  return const TrackingIdService();
});

class VoucherPreviewData {
  const VoucherPreviewData({
    required this.parcel,
    required this.qrPayload,
    required this.setup,
    this.splitChildren = const [],
  });

  final ParcelModel parcel;
  final String qrPayload;
  final AppSetupConfig setup;
  final List<ParcelModel> splitChildren;
}

final voucherPreviewProvider = FutureProvider.autoDispose
    .family<VoucherPreviewData, VoucherPreviewArgs>((ref, args) async {
      final settingsRepository = await ref.read(
        settingsRepositoryProvider.future,
      );
      final setup = await settingsRepository.getAppSetup();
      final townRepository = ref.read(townRepositoryProvider);
      final repository = ref.read(parcelRepositoryProvider);
      final now = DateTime.now();
      final sourceTown = args.form.fromTownCityCode.isNotEmpty
          ? null
          : await townRepository.getSourceTownByName(args.form.fromTown);
      final sourceCityCode = args.form.fromTownCityCode.isNotEmpty
          ? args.form.fromTownCityCode
          : sourceTown?.cityCode;
      if (sourceCityCode == null || sourceCityCode.isEmpty) {
        throw StateError('Selected source town is missing a city code.');
      }
      final staffProfile = await ref.read(staffProfileProvider.future);
      if (staffProfile == null) {
        throw StateError('Please sign in before creating a voucher.');
      }

      final issuingCityCode = staffProfile.branchCityCode ?? sourceCityCode;
      final issuingBranchId =
          staffProfile.branchId ??
          settingsRepository.branchIdForCityCode(sourceCityCode);
      if (issuingBranchId.isEmpty) {
        throw StateError('This account is missing an issuing branch.');
      }
      if (issuingCityCode.isEmpty) {
        throw StateError('This account is missing an issuing city code.');
      }

      final deviceId = await settingsRepository.getOrCreateDeviceId();
      final clientParcelId = '${deviceId}_${now.microsecondsSinceEpoch}';
      final runningNumber =
          await repository.countParcelsCreatedOnForCounter(
            now,
            issuingCityCode,
          ) +
          1;

      final trackingId = ref
          .read(trackingIdServiceProvider)
          .generate(
            cityCode: issuingCityCode,
            now: now,
            runningNumber: runningNumber,
          );

      final parcel = ParcelModel.create(
        clientParcelId: clientParcelId,
        trackingId: trackingId,
        deviceId: deviceId,
        branchId: issuingBranchId,
        fromTown: args.form.fromTown,
        toTown: args.form.toTown,
        cityCode: issuingCityCode,
        accountCode: setup.accountCode,
        senderName: args.form.senderName,
        senderPhone: args.form.senderPhone,
        receiverName: args.form.receiverName,
        receiverPhone: args.form.receiverPhone,
        parcelType: args.form.parcelType,
        numberOfParcels: args.form.numberOfParcels,
        totalCharges: args.form.totalCharges,
        paymentStatus: args.form.paymentStatus,
        cashAdvance: args.form.cashAdvance,
        parcelImagePath: args.form.parcelImagePath,
        remark: args.form.remark.isEmpty ? null : args.form.remark.trim(),
        now: now,
      );

      final qrPayload = ref
          .read(qrServiceProvider)
          .buildParcelPayload(trackingId: trackingId);

      final voucherSetup = _setupWithBranchProfile(setup, staffProfile);

      return VoucherPreviewData(
        parcel: parcel,
        qrPayload: qrPayload,
        setup: voucherSetup,
      );
    });

final voucherReprintPreviewProvider = FutureProvider.autoDispose
    .family<VoucherPreviewData, int>((ref, parcelId) async {
      final settingsRepository = await ref.read(
        settingsRepositoryProvider.future,
      );
      final setup = await settingsRepository.getAppSetup();
      final parcel = await ref
          .read(parcelRepositoryProvider)
          .getParcel(parcelId);
      if (parcel == null) {
        throw StateError('Parcel not found.');
      }
      var voucherSetup = setup;
      final branchId = parcel.branchId;
      if (branchId != null && branchId.isNotEmpty) {
        try {
          final branch = await ref
              .read(authRepositoryProvider)
              .fetchBranchProfile(branchId);
          voucherSetup = _setupWithBranchProfile(setup, branch);
        } catch (_) {
          voucherSetup = setup;
        }
      }

      final qrPayload = ref
          .read(qrServiceProvider)
          .buildParcelPayload(trackingId: parcel.trackingId);
      final splitChildren = parcel.parentParcelId == null
          ? await _loadSplitChildren(
              ref.read(parcelRepositoryProvider),
              parent: parcel,
            )
          : const <ParcelModel>[];

      return VoucherPreviewData(
        parcel: parcel,
        qrPayload: qrPayload,
        setup: voucherSetup,
        splitChildren: splitChildren,
      );
    });

Future<List<ParcelModel>> _loadSplitChildren(
  ParcelRepository repository, {
  required ParcelModel parent,
}) async {
  final parcels = await repository.getAllParcels();
  final children = parcels.where((parcel) {
    return _isChildOfParent(parcel, parent);
  }).toList();

  children.sort((a, b) {
    final indexCompare = _splitIndexSortValue(
      a,
    ).compareTo(_splitIndexSortValue(b));
    if (indexCompare != 0) {
      return indexCompare;
    }
    return a.createdAt.compareTo(b.createdAt);
  });
  return children;
}

bool _isChildOfParent(ParcelModel parcel, ParcelModel parent) {
  final parentId = parent.clientParcelId;
  final childParentId = parcel.parentParcelId;
  if (parentId != null &&
      parentId.isNotEmpty &&
      childParentId != null &&
      childParentId == parentId) {
    return true;
  }

  final parentTrackingId = parent.trackingId.toUpperCase();
  return parcel.trackingId.toUpperCase().startsWith('$parentTrackingId-') &&
      parcel.trackingId.length > parent.trackingId.length + 1;
}

int _splitIndexSortValue(ParcelModel parcel) {
  final index = parcel.splitIndex?.trim().toUpperCase();
  if (index != null && index.length == 1) {
    final code = index.codeUnitAt(0);
    if (code >= 65 && code <= 90) {
      return code - 65;
    }
  }

  final match = RegExp(
    r'-([A-Z])$',
    caseSensitive: false,
  ).firstMatch(parcel.trackingId);
  final fallback = match?.group(1)?.toUpperCase();
  if (fallback != null) {
    return fallback.codeUnitAt(0) - 65;
  }
  return 999;
}

AppSetupConfig _setupWithBranchProfile(
  AppSetupConfig setup,
  Object? branchProfile,
) {
  String? address;
  String? phoneNumbers;

  if (branchProfile is StaffProfile) {
    address = branchProfile.branchAddress;
    phoneNumbers = branchProfile.branchPhoneNumbers;
  } else if (branchProfile is BranchProfile) {
    address = branchProfile.address;
    phoneNumbers = branchProfile.phoneNumbers;
  }

  return setup.copyWith(
    businessAddress: address?.trim().isNotEmpty == true
        ? address!.trim()
        : setup.businessAddress,
    businessPhone: phoneNumbers?.trim().isNotEmpty == true
        ? phoneNumbers!.trim()
        : setup.businessPhone,
  );
}
