class StaffProfile {
  const StaffProfile({
    required this.userId,
    required this.role,
    required this.isActive,
    this.branchId,
    this.branchCityCode,
    this.branchTownName,
    this.branchType,
    this.branchAddress,
    this.branchPhoneNumbers,
  });

  final String userId;
  final String? branchId;
  final String role;
  final bool isActive;
  final String? branchCityCode;
  final String? branchTownName;
  final String? branchType;
  final String? branchAddress;
  final String? branchPhoneNumbers;

  bool get isAdmin => role == 'admin';

  bool get isStaff => role == 'staff';

  bool get isGate => branchType == 'gate';

  String get accessLabel {
    if (isAdmin) {
      return 'All branches';
    }
    if (branchCityCode == null || branchTownName == null) {
      return branchId ?? 'Branch not assigned';
    }
    return '$branchTownName ($branchCityCode)';
  }

  factory StaffProfile.fromMap(Map<String, dynamic> map) {
    final branch = map['branches'];
    final branchMap = branch is Map<String, dynamic> ? branch : null;

    return StaffProfile(
      userId: map['user_id'] as String,
      branchId: map['branch_id'] as String?,
      role: map['role'] as String,
      isActive: map['is_active'] as bool? ?? false,
      branchCityCode: branchMap?['city_code'] as String?,
      branchTownName: branchMap?['town_name'] as String?,
      branchType: branchMap?['branch_type'] as String?,
      branchAddress: branchMap?['address'] as String?,
      branchPhoneNumbers: branchMap?['phone_numbers'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'branch_id': branchId,
      'role': role,
      'is_active': isActive,
      'branches': {
        'city_code': branchCityCode,
        'town_name': branchTownName,
        'branch_type': branchType,
        'address': branchAddress,
        'phone_numbers': branchPhoneNumbers,
      },
    };
  }
}

class BranchProfile {
  const BranchProfile({
    required this.id,
    required this.townName,
    required this.cityCode,
    this.address,
    this.phoneNumbers,
  });

  final String id;
  final String townName;
  final String cityCode;
  final String? address;
  final String? phoneNumbers;

  factory BranchProfile.fromMap(Map<String, dynamic> map) {
    return BranchProfile(
      id: map['id'] as String,
      townName: map['town_name'] as String,
      cityCode: map['city_code'] as String,
      address: map['address'] as String?,
      phoneNumbers: map['phone_numbers'] as String?,
    );
  }
}
