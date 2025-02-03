import 'package:cw_core/utils/http_client.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// FIXME: Hardcoded values; Works only for monero

final dateFormat = DateFormat('yyyy-MM');
final dates = {
  "2014-5": 18844,
  "2014-6": 65406,
  "2014-7": 108882,
  "2014-8": 153594,
  "2014-9": 198072,
  "2014-10": 241088,
  "2014-11": 285305,
  "2014-12": 328069,
  "2015-1": 372369,
  "2015-2": 416505,
  "2015-3": 456631,
  "2015-4": 501084,
  "2015-5": 543973,
  "2015-6": 588326,
  "2015-7": 631187,
  "2015-8": 675484,
  "2015-9": 719725,
  "2015-10": 762463,
  "2015-11": 806528,
  "2015-12": 849041,
  "2016-1": 892866,
  "2016-2": 936736,
  "2016-3": 977691,
  "2016-4": 1015848,
  "2016-5": 1037417,
  "2016-6": 1059651,
  "2016-7": 1081269,
  "2016-8": 1103630,
  "2016-9": 1125983,
  "2016-10": 1147617,
  "2016-11": 1169779,
  "2016-12": 1191402,
  "2017-1": 1213861,
  "2017-2": 1236197,
  "2017-3": 1256358,
  "2017-4": 1278622,
  "2017-5": 1300239,
  "2017-6": 1322564,
  "2017-7": 1344225,
  "2017-8": 1366664,
  "2017-9": 1389113,
  "2017-10": 1410738,
  "2017-11": 1433039,
  "2017-12": 1454639,
  "2018-1": 1477201,
  "2018-2": 1499599,
  "2018-3": 1519796,
  "2018-4": 1542067,
  "2018-5": 1562861,
  "2018-6": 1585135,
  "2018-7": 1606715,
  "2018-8": 1629017,
  "2018-9": 1651347,
  "2018-10": 1673031,
  "2018-11": 1695128,
  "2018-12": 1716687,
  "2019-1": 1738923,
  "2019-2": 1761435,
  "2019-3": 1781681,
  "2019-4": 1803081,
  "2019-5": 1824671,
  "2019-6": 1847005,
  "2019-7": 1868590,
  "2019-8": 1890552,
  "2019-9": 1912212,
  "2019-10": 1932200,
  "2019-11": 1957040,
  "2019-12": 1978090,
  "2020-1": 2001290,
  "2020-2": 2022688,
  "2020-3": 2043987,
  "2020-4": 2066536,
  "2020-5": 2090797,
  "2020-6": 2111633,
  "2020-7": 2131433,
  "2020-8": 2153983,
  "2020-9": 2176466,
  "2020-10": 2198453,
  "2020-11": 2220000,
  "2020-12": 2242240,
  "2021-1": 2264584,
  "2021-2": 2286892,
  "2021-3": 2307079,
  "2021-4": 2329385,
  "2021-5": 2351004,
  "2021-6": 2373306,
  "2021-7": 2394882,
  "2021-8": 2417162,
  "2021-9": 2439490,
  "2021-10": 2461020,
  "2021-11": 2483377,
  "2021-12": 2504932,
  "2022-1": 2527316,
  "2022-2": 2549605,
  "2022-3": 2569711,
  "2022-4": 2591995,
  "2022-5": 2613603,
  "2022-6": 2635840,
  "2022-7": 2657395,
  "2022-8": 2679705,
  "2022-9": 2701991,
  "2022-10": 2723607,
  "2022-11": 2745899,
  "2022-12": 2767427,
  "2023-1": 2789763,
  "2023-2": 2811996,
  "2023-3": 2832118,
  "2023-4": 2854365,
  "2023-5": 2875972,
  "2023-6": 2898234,
  "2023-7": 2919771,
  "2023-8": 2942045,
  "2023-9": 2964280,
  "2023-10": 2985937,
  "2023-11": 3008178,
  "2023-12": 3029759
};

int getMoneroHeigthByDate({required DateTime date}) {
  final raw = '${date.year}' + '-' + '${date.month}';
  final lastHeight = dates.values.last;
  int startHeight;
  int endHeight;
  int height = 0;

  try {
    if ((dates[raw] == null) || (dates[raw] == lastHeight)) {
      startHeight = dates.values.toList()[dates.length - 2];
      endHeight = dates.values.toList()[dates.length - 1];
      final heightPerDay = (endHeight - startHeight) / 31;
      final endDateRaw = dates.keys.toList()[dates.length - 1].split('-');
      final endYear = int.parse(endDateRaw[0]);
      final endMonth = int.parse(endDateRaw[1]);
      final endDate = DateTime(endYear, endMonth);
      final differenceInDays = date.difference(endDate).inDays;
      final daysHeight = (differenceInDays * heightPerDay).round();
      height = endHeight + daysHeight;
    } else {
      startHeight = dates[raw]!;
      final index = dates.values.toList().indexOf(startHeight);
      endHeight = dates.values.toList()[index + 1];
      final heightPerDay = ((endHeight - startHeight) / 31).round();
      final daysHeight = (date.day - 1) * heightPerDay;
      height = startHeight + daysHeight - heightPerDay;
    }
  } catch (e) {
    printV(e.toString());
  }

  return height;
}

const havenDates = {
  "2023-05": 1352995,
  "2023-04": 1331460,
  "2023-03": 1309180,
  "2023-01": 1266810,
  "2022-12": 1244510,
  "2022-11": 1222970,
  "2022-10": 1200700,
  "2022-09": 1179140,
  "2022-08": 1156870,
  "2022-07": 1134600,
  "2022-06": 1113030,
  "2022-05": 1090800,
  "2022-04": 1069250,
  "2022-03": 1047000,
  "2022-02": 1026960,
  "2022-01": 1004700,
  "2021-12": 982400,
  "2021-11": 961000,
  "2021-10": 938600,
  "2021-09": 917000,
  "2021-08": 894800,
  "2021-07": 886000,
  "2021-06": 867300,
  "2021-05": 845000,
  "2021-04": 823500,
  "2021-03": 801500,
  "2021-02": 781000,
  "2021-01": 759000,
  "2020-12": 736500,
  "2020-11": 715000,
  "2020-10": 693000,
  "2020-09": 671000,
  "2020-08": 649000,
  "2020-07": 626600,
  "2020-06": 605000,
  "2020-05": 582700,
  "2020-04": 561100,
  "2020-03": 539000,
  "2020-02": 518000,
  "2020-01": 496000,
  "2019-12": 473400,
  "2019-11": 451900,
  "2019-10": 429600,
  "2019-09": 408000,
  "2019-08": 385700,
  "2019-07": 363800,
  "2019-06": 342200,
  "2019-05": 320000,
  "2019-04": 298400,
  "2019-03": 276000,
  "2019-02": 256000,
  "2019-01": 233700,
  "2018-12": 211400,
  "2018-11": 189800,
  "2018-10": 167500,
  "2018-09": 145900,
  "2018-08": 123700,
  "2018-07": 101400,
  "2018-06": 80000,
  "2018-05": 57550,
  "2018-04": 32000,
  "2018-03": 8500
};

DateTime formatMapKey(String key) => dateFormat.parse(key);

int getHavenHeightByDate({required DateTime date}) {
  String closestKey =
      havenDates.keys.firstWhere((key) => formatMapKey(key).isBefore(date), orElse: () => '');

  return havenDates[closestKey] ?? 0;
}

Future<int> getHavenCurrentHeight() async {
  final req = await getHttpClient()
    .getUrl(Uri.parse('https://explorer.havenprotocol.org/api/networkinfo'))
    .timeout(Duration(seconds: 15));
  final response = await req.close();
  final stringResponse = await response.transform(utf8.decoder).join();

  if (response.statusCode == 200) {
    final info = jsonDecode(stringResponse);
    return info['data']['height'] as int;
  } else {
    throw Exception('Failed to load current blockchain height');
  }
}

// Data taken from https://timechaincalendar.com/
const bitcoinDates = {
  "2024-08": 854889,
  "2024-07": 850182,
  "2024-06": 846005,
  "2024-05": 841590,
  "2024-04": 837182,
  "2024-03": 832623,
  "2024-02": 828319,
  "2024-01": 823807,
  "2023-12": 819206,
  "2023-11": 814765,
  "2023-10": 810098,
  "2023-09": 805675,
  "2023-08": 801140,
  "2023-07": 796640,
  "2023-06": 792330,
  "2023-05": 787733,
  "2023-04": 783403,
  "2023-03": 778740,
  "2023-02": 774525,
  "2023-01": 769810,
};

Future<int> getBitcoinHeightByDateAPI({required DateTime date}) async {
  final req = await getHttpClient()
    .getUrl(Uri.parse("https://mempool.cakewallet.com/api/v1/mining/blocks/timestamp/${(date.millisecondsSinceEpoch / 1000).round()}"))
    .timeout(Duration(seconds: 15));
  final response = await req.close();
  final stringResponse = await response.transform(utf8.decoder).join();

  return jsonDecode(stringResponse)['height'] as int;
}

int getBitcoinHeightByDate({required DateTime date}) {
  String dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
  final closestKey = bitcoinDates.keys
      .firstWhere((key) => formatMapKey(key).isBefore(date), orElse: () => bitcoinDates.keys.last);
  final beginningBlock = bitcoinDates[dateKey] ?? bitcoinDates[closestKey]!;

  final startOfMonth = DateTime(date.year, date.month);
  final daysDifference = date.difference(startOfMonth).inDays;

  // approximately 6 blocks per hour, 24 hours per day
  int estimatedBlocksSinceStartOfMonth = (daysDifference * 24 * 6);

  return beginningBlock + estimatedBlocksSinceStartOfMonth;
}

DateTime getDateByBitcoinHeight(int height) {
  final closestEntry = bitcoinDates.entries
      .lastWhere((entry) => entry.value >= height, orElse: () => bitcoinDates.entries.first);
  final beginningBlock = closestEntry.value;

  final startOfMonth = formatMapKey(closestEntry.key);
  final blocksDifference = height - beginningBlock;
  final hoursDifference = blocksDifference / 5.5;

  final estimatedDate = startOfMonth.add(Duration(hours: hoursDifference.ceil()));

  if (estimatedDate.isAfter(DateTime.now())) {
    return DateTime.now();
  }

  return estimatedDate;
}

int getLtcHeightByDate({required DateTime date}) {
  // TODO: use the proxy layer to get the height with a binary search of blocked header heights
  return 0;
}

// TODO: enhance all of this global const lists
const wowDates = {
  "2023-12": 583048,
  "2023-11": 575048,
  "2023-10": 566048,
  "2023-09": 558048,
  "2023-08": 549048,
  "2023-07": 540048,
  "2023-06": 532048,
  "2023-05": 523048,
  "2023-04": 514048,
  "2023-03": 505048,
  "2023-02": 497048,
  "2023-01": 488048,
  "2022-12": 479048,
  "2022-11": 471048,
  "2022-10": 462048,
  "2022-09": 453048,
  "2022-08": 444048,
  "2022-07": 435048,
  "2022-06": 427048,
  "2022-05": 418048,
  "2022-04": 410048,
  "2022-03": 401048,
  "2022-02": 393048,
  "2022-01": 384048,
  "2021-12": 375048,
  "2021-11": 367048,
  "2021-10": 358048,
  "2021-09": 349048,
  "2021-08": 340048,
  "2021-07": 331048,
  "2021-06": 322048,
  "2021-05": 313048,
  "2021-04": 305048,
  "2021-03": 295048,
  "2021-02": 287048,
  "2021-01": 279148,
  "2020-10": 252000,
  "2020-09": 243000,
  "2020-08": 234000,
  "2020-07": 225000,
  "2020-06": 217500,
  "2020-05": 208500,
  "2020-04": 199500,
  "2020-03": 190500,
  "2020-02": 183000,
  "2020-01": 174000,
  "2019-12": 165000,
  "2019-11": 156000,
  "2019-10": 147000,
  "2019-09": 138000,
  "2019-08": 129000,
  "2019-07": 120000,
  "2019-06": 112500,
  "2019-05": 103500,
  "2019-04": 94500,
  "2019-03": 85500,
  "2019-02": 79500,
  "2019-01": 73500,
  "2018-12": 67500,
  "2018-11": 61500,
  "2018-10": 52500,
  "2018-09": 45000,
  "2018-08": 36000,
  "2018-07": 27000,
  "2018-06": 18000,
  "2018-05": 9000,
  "2018-04": 1
};

int getWowneroHeightByDate({required DateTime date}) {
  String closestKey =
      wowDates.keys.firstWhere((key) => formatMapKey(key).isBefore(date), orElse: () => '');

  return wowDates[closestKey] ?? 0;
}
