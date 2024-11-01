import 'package:cake_wallet/exchange/provider/trocador_exchange_provider.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:mobx/mobx.dart';

part 'trocador_providers_view_model.g.dart';

class TrocadorProvidersViewModel = TrocadorProvidersViewModelBase with _$TrocadorProvidersViewModel;

abstract class TrocadorProvidersViewModelBase with Store {
  TrocadorProvidersViewModelBase(this._settingsStore, this.trocadorExchangeProvider) {
    fetchTrocadorPartners();
  }

  final SettingsStore _settingsStore;
  final TrocadorExchangeProvider trocadorExchangeProvider;

  @observable
  ObservableFuture<Map<String, bool>>? fetchProvidersFuture;

  Map<String, String> providerRatings = {};

  @computed
  bool get isLoading => fetchProvidersFuture?.status == FutureStatus.pending;

  @action
  Future<void> fetchTrocadorPartners() async {
    fetchProvidersFuture =
        ObservableFuture(trocadorExchangeProvider.fetchProviders().then((providers) {
      var providerNames = providers.map((e) => e.name).toList();

      providerRatings = {
        for (var provider in providers)
          provider.name: provider.rating
      };

      return _settingsStore
          .updateAllTrocadorProviderStates(providerNames)
          .then((_) => _settingsStore.trocadorProviderStates);
    }));
  }

  @computed
  Map<String, bool> get providerStates => _settingsStore.trocadorProviderStates;

  @action
  void toggleProviderState(String providerName) {
    final currentState = providerStates[providerName] ?? false;
    _settingsStore.setTrocadorProviderState(providerName, !currentState);
  }
}
