import 'package:cw_zano/api/model/receive.dart';

class EmployedEntries {
  final List<Receive> receive;
  final List<Receive> send;

  EmployedEntries({required this.receive, required this.send});

  factory EmployedEntries.fromJson(Map<String, dynamic> json) =>
      EmployedEntries(
        receive: json['receive'] == null ? [] : (json['receive'] as List<dynamic>)
            .map((e) => Receive.fromJson(e as Map<String, dynamic>))
            .toList(),
        send: json['spent'] == null ? [] : (json['spent'] as List<dynamic>)
            .map((e) => Receive.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
