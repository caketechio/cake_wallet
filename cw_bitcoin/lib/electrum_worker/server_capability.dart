import 'package:bitcoin_base/bitcoin_base.dart';

class ServerCapability {
  static const ELECTRS_MIN_BATCHING_VERSION = ElectrumVersion(0, 9, 0);
  static const FULCRUM_MIN_BATCHING_VERSION = ElectrumVersion(1, 6, 0);
  static const MEMPOOL_ELECTRS_MIN_BATCHING_VERSION = ElectrumVersion(3, 1, 0);

  bool supportsBatching;
  bool supportsTxVerbose;
  String version;

  ServerCapability({
    required this.supportsBatching,
    required this.supportsTxVerbose,
    required this.version,
  });

  static ServerCapability fromVersion(List<String> serverVersion) {
    if (serverVersion.isNotEmpty) {
      final server = serverVersion.first.toLowerCase();

      if (server.contains('electrumx')) {
        return ServerCapability(
          supportsBatching: true,
          supportsTxVerbose: true,
          version: server,
        );
      }

      if (server.startsWith('electrs/')) {
        var electrsVersion = server.substring('electrs/'.length);
        final dashIndex = electrsVersion.indexOf('-');
        if (dashIndex > -1) {
          electrsVersion = electrsVersion.substring(0, dashIndex);
        }

        try {
          final version = ElectrumVersion.fromStr(electrsVersion);
          if (version.compareTo(ELECTRS_MIN_BATCHING_VERSION) >= 0) {
            return ServerCapability(
              supportsBatching: true,
              supportsTxVerbose: false,
              version: server,
            );
          }
        } catch (e) {
          // ignore version parsing errors
        }

        return ServerCapability(
          supportsBatching: false,
          supportsTxVerbose: false,
          version: server,
        );
      }

      if (server.startsWith('fulcrum')) {
        final fulcrumVersion = server.substring('fulcrum'.length).trim();

        try {
          final version = ElectrumVersion.fromStr(fulcrumVersion);
          if (version.compareTo(FULCRUM_MIN_BATCHING_VERSION) >= 0) {
            return ServerCapability(
              supportsBatching: true,
              supportsTxVerbose: true,
              version: server,
            );
          }
        } catch (e) {}
      }

      if (server.startsWith('mempool-electrs')) {
        var mempoolElectrsVersion = server.substring('mempool-electrs'.length).trim();
        final dashIndex = mempoolElectrsVersion.indexOf('-');

        if (dashIndex > -1) {
          mempoolElectrsVersion = mempoolElectrsVersion.substring(0, dashIndex);
        }

        try {
          final version = ElectrumVersion.fromStr(mempoolElectrsVersion);
          if (version.compareTo(MEMPOOL_ELECTRS_MIN_BATCHING_VERSION) > 0) {
            return ServerCapability(
              supportsBatching: true,
              supportsTxVerbose: false,
              version: server,
            );
          }
        } catch (e) {
          // ignore version parsing errors
        }
      }
    }

    return ServerCapability(
      supportsBatching: false,
      supportsTxVerbose: false,
      version: "unknown",
    );
  }
}
