import '../../data/models/town.dart';

class DefaultTowns {
  const DefaultTowns._();

  static const sourceTowns = <TownModel>[
    TownModel(
      townName: 'တောင်ကြီး',
      type: TownType.source,
      cityCode: 'TGI',
      sortOrder: 0,
    ),
    TownModel(
      townName: 'လားရှိုး',
      type: TownType.source,
      cityCode: 'LSO',
      sortOrder: 1,
    ),
    TownModel(
      townName: 'တာချီလိတ်',
      type: TownType.source,
      cityCode: 'TCL',
      sortOrder: 2,
    ),
  ];

  static const destinationTowns = <TownModel>[
    TownModel(townName: 'ကာလိ', type: TownType.destination, sortOrder: 1),
    TownModel(townName: 'ကွန်ဟိန်း', type: TownType.destination, sortOrder: 2),
    TownModel(townName: 'ကောင်းလမ်း', type: TownType.destination, sortOrder: 3),
    TownModel(townName: 'ကျိုင်းတုံ', type: TownType.destination, sortOrder: 4),
    TownModel(townName: 'ကျေးသီး', type: TownType.destination, sortOrder: 5),
    TownModel(townName: 'ကုန်းသာ', type: TownType.destination, sortOrder: 6),
    TownModel(townName: 'ခိုလမ်', type: TownType.destination, sortOrder: 7),
    TownModel(townName: 'ဆင်မောင်း', type: TownType.destination, sortOrder: 8),
    TownModel(townName: 'တာကော်', type: TownType.destination, sortOrder: 9),
    TownModel(townName: 'တာချီလိတ်', type: TownType.destination, sortOrder: 10),
    TownModel(townName: 'တာလေ', type: TownType.destination, sortOrder: 11),
    TownModel(townName: 'တောင်ကြီး', type: TownType.destination, sortOrder: 12),
    TownModel(townName: 'တုံတာ', type: TownType.destination, sortOrder: 13),
    TownModel(townName: 'နမ့်စန်', type: TownType.destination, sortOrder: 14),
    TownModel(townName: 'နမ့်ပေါင်', type: TownType.destination, sortOrder: 15),
    TownModel(townName: 'နမ့်လန်', type: TownType.destination, sortOrder: 16),
    TownModel(townName: 'နောင်မွန်', type: TownType.destination, sortOrder: 17),
    TownModel(townName: 'ပင်လုံ', type: TownType.destination, sortOrder: 18),
    TownModel(townName: 'ပန်ကေသု', type: TownType.destination, sortOrder: 19),
    TownModel(
      townName: 'မိုင်းကိုင်',
      type: TownType.destination,
      sortOrder: 20,
    ),
    TownModel(townName: 'မိုင်းစံ', type: TownType.destination, sortOrder: 21),
    TownModel(
      townName: 'မိုင်းနန်း',
      type: TownType.destination,
      sortOrder: 22,
    ),
    TownModel(
      townName: 'မိုင်းနောင်',
      type: TownType.destination,
      sortOrder: 23,
    ),
    TownModel(
      townName: 'မိုင်းပွန်',
      type: TownType.destination,
      sortOrder: 24,
    ),
    TownModel(
      townName: 'မိုင်းပျဥ်း',
      type: TownType.destination,
      sortOrder: 25,
    ),
    TownModel(
      townName: 'မိုင်းဖြတ်',
      type: TownType.destination,
      sortOrder: 26,
    ),
    TownModel(townName: 'မိုင်းရယ်', type: TownType.destination, sortOrder: 27),
    TownModel(townName: 'လားရှိုး', type: TownType.destination, sortOrder: 28),
    TownModel(townName: 'လဲချား', type: TownType.destination, sortOrder: 29),
    TownModel(townName: 'လွိုင်လင်', type: TownType.destination, sortOrder: 30),
    TownModel(townName: 'ဝမ်စိမ်း', type: TownType.destination, sortOrder: 31),
    TownModel(townName: 'ဝမ်ဟိုင်း', type: TownType.destination, sortOrder: 32),
    TownModel(townName: 'ဟိုပုံး', type: TownType.destination, sortOrder: 33),
  ];

  static const all = <TownModel>[...sourceTowns, ...destinationTowns];
}
