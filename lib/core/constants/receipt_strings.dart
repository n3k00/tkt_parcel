import '../../data/models/enums/payment_status.dart';

abstract final class ReceiptStrings {
  static const defaultBusinessName = 'သိင်္ခသူ';
  static const defaultBusinessSubtitle = 'ခရီးသည် နှင့် ကုန်စည် ပို့ဆောင်ရေး';
  static const defaultBusinessAddress = 'ပါဆပ်ကားလေးကွင်း၊တာချီလိတ်မြို့။';
  static const defaultBusinessPhone = '09250787547,09253003004';
  static const defaultFooter = '';
  static const thankYou = 'ကျေးဇူးတင်ပါသည်';
  static const termsTitle = 'စည်းကမ်းချက်များ';
  static const voucherTerms = [
    'ကုန်ပစ္စည်းများ ရန်သူမျိုးငါးပါးကြောင့် ပျက်စီးပါက တာဝန်မယူပါ။',
    'ရေစိုမခံသော ပစ္စည်းများကို ရေစိုခံအောင် ထုပ်ပိုးပေးပါ။',
    'ကုန်ပစ္စည်းများကို ဂိတ်တွင် (၇) ရက်သာ သိမ်းဆည်းပေးထားပါမည်။',
    'တန်ဖိုးမဖော်ပြသော ကုန်ပစ္စည်းများ ပျောက်ဆုံးပါက တန်ဆာ၏ (၁၀) ဆကိုသာ ပေးလျော်ပါမည်။',
    'ငွေစက္ကူများ၊ ထီလက်မှတ်များ၊ ရွှေ၊ ငွေ နှင့် အဖိုးတန်ပစ္စည်းများ လျှို့ဝှက်ပေးပို့ခြင်း ခွင့်မပြုပါ။',
    'ပုပ်သိုးလွယ်သော ပစ္စည်းများ အကြောင်းအမျိုးမျိုးကြောင့် ရက်လွန်ပျက်စီးပါက တာဝန်မယူပါ။',
    'ဥပဒေနှင့်မလွတ်ကင်းသော ပစ္စည်းများ တင်ဆောင်ခြင်း (လုံးဝ) ခွင့်မပြုပါ။',
  ];

  static const trackingIdLabel = 'ဘောင်ချာနံပါတ်';
  static const createdAtLabel = 'အချိန်နှင့်ရက်စွဲ';
  static const fromTownLabel = 'လက်ခံသည် မြို့';
  static const toTownLabel = 'ပို့မည့် မြို့';
  static const senderNameLabel = 'ပေးပို့သူအမည်';
  static const receiverNameLabel = 'လက်ခံသူအမည်';
  static const parcelTypeLabel = 'အမျိုးအစား';
  static const parcelCountLabel = 'အရေအတွက်';
  static const totalChargesLabel = 'ပို့ဆောင်ခ';
  static const paymentStatusLabel = 'ငွေပေးချေမှု';
  static const cashAdvanceLabel = 'စိုက်ငွေ';
  static const remarkLabel = 'မှတ်ချက်';
  static const paidLabel = 'ငွေရှင်းပြီး';
  static const unpaidLabel = 'ငွေတောင်းရန်';

  static const sampleTrackingId = 'TGI-A1-260319-0003';
  static const sampleFromTown = 'တောင်ကြီး';
  static const sampleToTown = 'တာချီလိတ်';
  static const sampleSenderName = 'နန္ဒာလှ';
  static const sampleSenderPhone = '52388';
  static const sampleReceiverName = 'မအမာ';
  static const sampleReceiverPhone = '8368';
  static const sampleParcelType = 'အကြီး';
  static const sampleQrPayload = sampleTrackingId;
}

extension ReceiptPaymentStatusX on PaymentStatus {
  String get receiptLabel {
    switch (this) {
      case PaymentStatus.paid:
        return ReceiptStrings.paidLabel;
      case PaymentStatus.unpaid:
        return ReceiptStrings.unpaidLabel;
    }
  }
}
