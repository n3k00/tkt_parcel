import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VoucherQrView extends StatelessWidget {
  const VoucherQrView({
    super.key,
    required this.payload,
  });

  final String payload;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: payload,
      size: 120,
      backgroundColor: Colors.white,
    );
  }
}
