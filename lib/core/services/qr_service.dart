class QrService {
  String buildParcelPayload({
    required String trackingNumber,
    required String receiverName,
  }) {
    return 'tracking=$trackingNumber;receiver=$receiverName';
  }
}
