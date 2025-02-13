# Guide to adding a new wallet type in Cake Wallet

## Wallet Integration

**N:B** Throughout this guide, `walletx` refers to the specific wallet type you want to add. If you're adding `BNB` to CakeWallet, then `walletx` for you here is `bnb`.

**Core Folder/Files Setup**
- Identify your core component/package (major project component), which would power the integration e.g web3dart, solana, onchain etc
- Add a new entry to `WalletType` class in `cw_core/wallet_type.dart`. 
- Fill out the necessary information in the various functions in the files, concerning the wallet name, the native currency type, symbol etc.
- Go to `cw_core/lib/currency_for_wallet_type.dart`, in the `currencyForWalletType` function, add a case for `walletx`, returning the native cryptocurrency for `walletx`. 
- If the cryptocurrency for walletx is not available among the default cryptocurrencies, add a new cryptocurrency entry in `cw_core/lib/cryptocurrency.dart`. 
- Add the newly created cryptocurrency name to the list named `all` in this file.
- Create a package for the wallet specific integration, name it. `cw_walletx`
- Add the following initial common files and replicate to fit the wallet
    - walletx_transaction_history.dart
    - walletx_transaction_info.dart
    - walletx_mnemonics_exception.dart
    - walletx_tokens.dart
    - walletx_wallet_service.dart:
    - walletx_wallet.dart
    - etc.

- Add the code to run the code generation needed for the files in the `cw_walletx` package to the `model_generator.sh` script

		 cd cw_walletx && flutter pub get && dart run build_runner build --delete-conflicting-outputs && cd ..

- Add the relevant dev_dependencies for generating the files also
    - build_runner
    - mobx_codegen
    - hive_generator

**WalletX Proxy Setup**

A `Proxy` class is used to communicate with the specific wallet package we have. Instead of directly making use of methods and parameters in `cw_walletx` within the `lib` directory, we use a proxy to access these data. All important functions, calls and interactions we want to make with our `cw_walletx` package would be defined and done through the proxy class. The class would define the import

-  Create a proxy folder titled `walletx` to handle the wallet operations. It would contain 2 files: `cw_walletx.dart` and `walletx.dart`.
- `cw_walletx.dart` file would hold an implementation class containing major operations to be done in the lib directory. It serves as the link between the cw_walletx package and the rest of the codebase(lib directory files and folders).
- `walletx.dart` would contain the abstract class highlighting the methods that would bring the functionalities and features in the `cw_walletx` package to the rest of the `lib` directory.
- Add `walletx.dart` to `.gitignore` as we won’t be pushing it: `lib/tron/tron.dart`.
- `walletx.dart` would always be generated based on the configure files we would be setting up in the next step. 

**Configuration Files Setup**
- Before we populate the field, head over to `tool/configure.dart` to setup the necessary configurations for the `walletx` proxy.
- Define the output path, it’ll follow the format `lib/walletx/walletx.dart`.
- Add the variable to check if `walletx` is to be activated
- Define the function that would generate the abstract class for the proxy.(We will flesh out this function in the next steps).
- Add the defined variable in step 2 to the `generatePubspec` and `generateWalletTypes`.
- Next, modify the following functions:
    - generatePubspec function
	1. Add the parameters to the method params (i.e required bool hasWalletX)
	2. Define a variable to hold the entry for the pubspec.yaml file

            const cwWalletX = """
  			cw_tron:
    		  path: ./cw_walletx
    		  """;

    3. Add an if block that takes in the passed parameter and adds the defined variable(inn the previous step) to the list of outputs		
            
            if (hasWalletX) {
    			      output += '\n$cwWalletX’;
  			  }

	- generateWalletTypes function
	1. Add the parameters to the method params (i.e required bool hasWalletX)
	2. Add an if block to add the wallet type to the list of outputs this function generates			  

            if (hasWalletX) {
    				outputContent += '\tWalletType.walletx,\n’;
 			  }
              
- Head over to `scripts/android/pubspec_gen.sh` script, and modify the `CONFIG_ARGS` under `$CAKEWALLET`. Add `"—walletx”` to the end of the passed in params.
- Repeat this in `scripts/ios/app_config.sh` and `scripts/macos/app_config.sh`
- Open a terminal and cd into `scripts/android/`. Run the following commands to run setup configuration scripts(proxy class, add walletx to list of wallet types and add cw_walletx to pubspec).

		source ./app_env.sh cakewallet

		./app_config.sh

		cd cw_walletx && flutter pub get && dart run build_runner build

		dart run build_runner build --delete-conflicting-outputs

Moving forward, our interactions with the cw_walletx package would be through the proxy class and its methods.

**Pre-Wallet Creation for WalletX**
- Go to `di.dart` and locate the block to `registerWalletService`. In this, add the case to handle creating the WalletXWalletService
				
      case WalletType.walletx:
		return walletx!.createWalletXWalletService(_walletInfoSource);
    
- Go to `lib/view_model/wallet_new_vm.dart`, in the getCredentials method, which gets the new wallet credentials for walletX add the case for the new wallet
	
      case WalletType.walletx:
		return walletx!.createWalletXNewWalletCredentials(name: name);

**Node Setup**
- Before we can be able to successfully create a new wallet of wallet type walletx we need to setup the node that the wallet would use:
- In the assets directory, create a new file and name it `walletx_node_list.yml`. This yml file would contain the details for nodes to be used for walletX. An example structure for each node entry 
	
      uri: "api.nodeurl.io" 
	  is_default: true
	  useSSL: true

You can add as many node entries as desired.

- Add the path to the yml file created to the `pubspec_base.yaml` file (`“assets/walletx_node_list.yml”`)
- Go to `lib/entities/node_list.dart`, add a function to load the node entries we made in `walletx_node_list.yml` for walletx. 
- Name your function `loadDefaultWalletXNodes()`. The function would handle loading the yml file as a string and parsing it into a Node Object to be used within the app. Here’s a template for the function.
		
		Future<List<Node>> loadDefaultWalletXNodes() async {
		  	final nodesRaw = await rootBundle.loadString('assets/tron_node_list.yml');
  			final loadedNodes = loadYaml(nodesRaw) as YamlList;
 			final nodes = <Node>[];
			for (final raw in loadedNodes) {
				if (raw is Map) {
					final node = Node.fromMap(Map<String, Object>.from(raw));
					node.type = WalletType.tron;
					nodes.add(node);
					}
			}
  		   return nodes;
	 }

- Inside the `resetToDefault` function, call the function you created and add the result to the nodes result variable.
- Go to `lib/entities/default_settings_migration.dart` file, we’ll be adding the following to the file.
- At the top of the file, after the imports, define the default nodeUrl for wallet-name.
- Next, write a function to fetch the node for this default uri you added above.

		Node? getWalletXDefaultNode({required Box<Node> nodes}) {
			return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == walletXDefaultNodeUri) ??
				nodes.values.firstWhereOrNull((node) => node.type == WalletType.walletx);
		}

- Next, write a function that will add the list of nodes we declared in the `walletx_node_list.yml` file to the Nodes Box, to be used in the app. Here’s the format for this function
		
	  Future<void> addWalletXNodeList({required Box<Node> nodes}) async {
		final nodeList = await loadDefaultWalletXNodes();
		for (var node in nodeList) {
				if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
					await nodes.add(node);
				}
			}
		}

- Next, we’ll write the function to change walletX current node to default. A handy function we would make use of later on. Add a new preference key in `lib/entities/preference_key.dart` with the format `PreferencesKey.currentWalletXNodeIdKey`, we’ll use it to identify the current node id.

		Future<void> changeWalletXCurrentNodeToDefault(
				{required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
			final node = getWalletXDefaultNode(nodes: nodes);
			final nodeId = node?.key as int? ?? 0;
			await sharedPreferences.setInt(PreferencesKey.currentWalletXNodeIdKey, nodeId);
		}

- Next, in the `defaultSettingsMigration` function at the top of the file, add a new case to handle both `addWalletXNodeList` and `changeWalletXCurrentNodeToDefault`
			
		case “next-number-increment”:
			await addWalletXNodeList(nodes: nodes);
			await changeWalletXCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
			break;

- Next, increase the `initialMigrationVersion` number in `main.dart` to be the new case entry number you entered in the step above for the `defaultSettingsMigration` function.
- Next, go to `lib/view_model/node_list/node_list_view_model.dart`  
- In the `reset` function, add a case for walletX:			

		case WalletType.tron:
        	node = getTronDefaultNode(nodes: _nodeSource)!;
			break;

- Lastly, go to `cw_core/lib/node.dart`, 
- In the uri getter, add a case to handle the uri setup for walletX. If the node uses http, return `Uri.http`, if not, return `Uri.https`
		
		case WalletType.walletX:
				return Uri.https(uriRaw, ‘’);
	
- Also, in the `requestNode` method, add a case for `WalletType.walletx`
- Next is the modifications to `lib/store/settings_store.dart` file:
- In the `load` function, create a variable to fetch the currentWalletxNodeId using the `PreferencesKey.currentWalletXNodeIdKey` we created earlier.
- Create another variable `walletXNode` which gets the walletx node using the nodeId variable assigned in the step above.
- Add a check to see if walletXNode is not null, if it’s not null,   assign the created tronNode variable to  the nodeMap with a type of walletX 
    								
		final walletXNode = nodeSource.get(walletXNodeId);
		final walletXNodeId = sharedPreferences.getInt(PreferencesKey.currentWalletXNodeIdKey);								
		if (walletXNode != null) {
			nodes[WalletType.walletx] = walletXNode;
		}

- Repeat the steps above in the `reload` function
- Next, add a case for walletX in the `_saveCurrentNode` function.

- Run the following commands after to generate modified files in cw_core  and lib		
		
		cd cw_core && flutter pub get && dart run build_runner build --delete-conflicting-outputs && cd ..

		dart run build_runner build --delete-conflicting-outputs

- Lastly, before we run the app to test what we’ve done so far, 
- Go to `lib/src/dashboard/widgets/menu_widget.dart` and add an icon for walletX to be used within the app.				
- Go to `lib/src/screens/wallet_list/wallet_list_page.dart` and add an icon for walletx, add a case for walletx also in the `imageFor` method.
- Do the same thing in `lib/src/screens/dashboard/desktop_widgets/desktop_wallet_selection_dropdown.dart`

- One last thing before we can create a wallet for walletx, go to `lib/view_model/wallet_new_vm.dart`
- Modify the `seedPhraseWordsLength` getter by adding a case for `WalletType.walletx`

Now you can run the codebase and successfully create a wallet for type walletX successfully.

**Display Seeds/Keys**
- Next, we want to set up our wallet to display the seeds and/or keys in the security page of the app.
-  Go to `lib/view_model/wallet_keys_view_model.dart`
- Modify the `populateItems` function by adding a case for `WalletType.walletx` in it.
- Now your seeds and/or keys should display when you go to Security and Backup -> Show seed/keys page within the app.

**Restore Wallet**
- Go to `lib/core/seed_validator.dart`
- In the `getWordList` method, add a case to handle `WalletType.walletx` which would return the word list to be used to validate the passed in seeds.
- Next, go to `lib/wallet_restore_view_model.dart`
- Modify the `hasRestoreFromPrivateKey` to reflect if walletx supports restore from Key
- Add a switch case to handle the various restore modes that walletX supports 
- Modify the `getCredential` method to handle the restore flows for `WalletType.walletx`
- Run the build_runner code generation command

**Receive** 
- Go to `lib/view_model/wallet_address_list/wallet_address_list_view_model.dart`
- Create an implementation of `PaymentUri` for type WalletX.
- In the uri getter, add a case for `WalletType.walletx` returning the implementation class for `PaymentUri`
- Modify the `addressList` getter to return the address/addresses for walletx

**Balance Screen**
- Go to `lib/view_model/dashboard/balance_view_model.dart`
- Modify the function to adjust the way the balance is being displayed on the app: `isHomeScreenSettingsEnabled` 
- Add a case to the `availableBalanceLabel` getter to modify the text being displayed (Available or confirmed)
- Same for `additionalBalanceLabel` 
- Next, go to `lib/reactions/fiat_rate_update.dart`
- Modify the `startFiatRateUpdate` function and add a check for `WalletType.walletx` to return all the token currencies
- Next, go to `lib/reactions/on_current_wallet_change.dart`
- Modify the `startCurrentWalletChangeReaction` function and add a check for `WalletType.walletx` to return all the token currencies
- Lastly, go to `lib/view_model/dashboard/transaction_list_item.dart`
- In the `formattedFiatAmount` getter, add a case to handle the fiat amount conversion for `WalletType.walletx`

**Send ViewModel**
- Go to `lib/view_model/send/send_view_model.dart`
- Modify the `_credentials` function to reflect `WalletType.walletx`
- Modify `hasMultipleTokens` to reflect wallets

**Exchange**
- Go to lib/view_model/exchange/exchange_view_model.dart
- First, add a case for WalletType.walletx in the `initialPairBasedOnWallet` method.
- If WalletX supports tokens, go to `lib/view_model/exchange/exchange_trade_view_model.dart`
- Modify the `_checkIfCanSend` method by creating a `_isWalletXToken` that checks if the from currency is WalletX and if its tag is for walletx
- Add `_isWalletXToken` to the return logic for the method.

**Secrets**
- Create a json file named `wallet-secrets-config.json` and put an empty curly bracket “{}” in it
- Add a new entry to `tool/utils/secret_key.dart` for walletx
- Modify the `tool/generate_secrets_config.dart` file for walletx, don’t forget to call `secrets.clear()` before adding a new set of generation logic
- Modify the `tool/import_secrets_config.dart` file for walletx
- In the `.gitignore` file, add `**/tool/.walletx-secrets-config.json` and `**/cw_walletx/lib/.secrets.g.dart`

**HomeSettings: WalletX Tokens Display and Management** 
- Go to `lib/view_model/dashboard/home_settings_view_model.dart`
- Modify the `_updateTokensList` method to add all walletx tokens if the wallet type is `WalletType.walletx`.
- Modify the `getTokenAddressBasedOnWallet` method to include a case to fetch the address for a WalletX token.
- Modify the `getToken` method to return a specific walletx token
- Modify the `addToken`, `deleteToken` and `changeTokenAvailability` methods to handle cases where the walletType is walletx
        	
**Buy and Sell WalletX**
- Go to `lib/entities/provider_types.dart`
- Add a case for `WalletType.walletx` in the `getAvailableBuyProviderTypes` method. Return a list of providers that support buying WalletX.
- Add a case for `WalletType.walletx` in the `getAvailableSellProviderTypes` method. Return a list of providers that support selling WalletX.

**Restore QR setup**
- Go to `lib/view_model/restore/wallet_restore_from_qr_code.dart`
- Add the scheme for walletx  in `_walletTypeMap` 
- Also modify `_determineWalletRestoreMode` to include a case for walletx
- Go to `lib/view_model/restore/restore_from_qr_vm.dart` 
- Modify `getCredentialsFromRestoredWallet` method
- Go to `lib/core/address_validator.dart`
- Modify the `getAddressFromStringPattern` method to add a case for `WalletType.walletx`
- and if it has tokens (ex. erc20, trc20, spl tokens) then add them to the switch case as well
- Add the scheme for walletx for both Android in `AndroidManifestBase.xml` and iOS in `InfoBase.plist`

**Transaction History**
- Go to `lib/view_model/transaction_details_view_model.dart`
- Add a case for `WalletType.walletx` to add the items to be displayed on the detailed view
- Modify the `_explorerUrl` method to add the blockchain explorer link for WalletX in order to view the more info on a transaction 
- Modify the  `_explorerDescription` to display the name of the explorer




# Points to note when adding the new wallet type

1. if it has tokens (ex. ERC20, SPL, etc...) make sure to add that to this function `_checkIfCanSend` in `exchange_trade_view_model.dart`
1. if it has tokens (ex. ERC20, SPL, etc...) make sure to add a check for the tags as well in the 
2. Check On/Off ramp providers that support the new wallet currency and add them accordingly in `provider_types.dart`
3. Add support for wallet uri scheme to restore from QR for both Android in `AndroidManifestBase.xml` and iOS in `InfoBase.plist`
4. Make sure no imports are using the wallet internal package files directly, instead use the proxy layers that is created in the main lib `lib/cw_ethereum.dart` for example. (i.e try building Monero.com if you get compilation errors, then you probably missed something)


Copyright (C) 2018-2023 Cake Labs LLC
