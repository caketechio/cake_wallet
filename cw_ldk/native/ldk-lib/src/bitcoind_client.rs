use crate::convert::{BlockchainInfo, FeeResponse, FundedTx, NewAddress, RawTx, SignedTx};
use base64;
use bitcoin::blockdata::block::Block;
use bitcoin::blockdata::transaction::Transaction;
use bitcoin::consensus::encode;
use bitcoin::hash_types::{BlockHash, Txid};
use bitcoin::util::address::Address;
use lightning::chain::chaininterface::{BroadcasterInterface, ConfirmationTarget, FeeEstimator};
use lightning_block_sync::http::HttpEndpoint;
use lightning_block_sync::rpc::RpcClient;
use lightning_block_sync::{AsyncBlockSourceResult, BlockHeaderData, BlockSource};
use serde_json;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;

pub struct BitcoindClient {
	bitcoind_rpc_client: Arc<Mutex<RpcClient>>,
	host: String,
	port: u16,
	rpc_user: String,
	rpc_password: String,
	fees: Arc<HashMap<Target, AtomicU32>>,
	handle: tokio::runtime::Handle,
}

#[derive(Clone, Eq, Hash, PartialEq)]
pub enum Target {
	Background,
	Normal,
	HighPriority,
}

impl BlockSource for &BitcoindClient {
	fn get_header<'a>(
		&'a mut self, header_hash: &'a BlockHash, height_hint: Option<u32>,
	) -> AsyncBlockSourceResult<'a, BlockHeaderData> {
		Box::pin(async move {
			let mut rpc = self.bitcoind_rpc_client.lock().await;
			rpc.get_header(header_hash, height_hint).await
		})
	}

	fn get_block<'a>(
		&'a mut self, header_hash: &'a BlockHash,
	) -> AsyncBlockSourceResult<'a, Block> {
		Box::pin(async move {
			let mut rpc = self.bitcoind_rpc_client.lock().await;
			rpc.get_block(header_hash).await
		})
	}

	fn get_best_block<'a>(&'a mut self) -> AsyncBlockSourceResult<(BlockHash, Option<u32>)> {
		Box::pin(async move {
			let mut rpc = self.bitcoind_rpc_client.lock().await;
			rpc.get_best_block().await
		})
	}
}

/// The minimum feerate we are allowed to send, as specify by LDK.
const MIN_FEERATE: u32 = 253;

impl BitcoindClient {
	pub async fn new(
		host: String, port: u16, rpc_user: String, rpc_password: String,
		handle: tokio::runtime::Handle,
	) -> std::io::Result<Self> {
		let http_endpoint = HttpEndpoint::for_host(host.clone()).with_port(port);
		let rpc_credentials =
			base64::encode(format!("{}:{}", rpc_user.clone(), rpc_password.clone()));
		let mut bitcoind_rpc_client = RpcClient::new(&rpc_credentials, http_endpoint)?;
		let _dummy = bitcoind_rpc_client
			.call_method::<BlockchainInfo>("getblockchaininfo", &vec![])
			.await
			.map_err(|_| {
				std::io::Error::new(std::io::ErrorKind::PermissionDenied,
				"Failed to make initial call to bitcoind - please check your RPC user/password and access settings")
			})?;
		let mut fees: HashMap<Target, AtomicU32> = HashMap::new();
		fees.insert(Target::Background, AtomicU32::new(MIN_FEERATE));
		fees.insert(Target::Normal, AtomicU32::new(2000));
		fees.insert(Target::HighPriority, AtomicU32::new(5000));
		let client = Self {
			bitcoind_rpc_client: Arc::new(Mutex::new(bitcoind_rpc_client)),
			host,
			port,
			rpc_user,
			rpc_password,
			fees: Arc::new(fees),
			handle: handle.clone(),
		};
		BitcoindClient::poll_for_fee_estimates(
			client.fees.clone(),
			client.bitcoind_rpc_client.clone(),
			handle,
		);
		Ok(client)
	}

	fn poll_for_fee_estimates(
		fees: Arc<HashMap<Target, AtomicU32>>, rpc_client: Arc<Mutex<RpcClient>>,
		handle: tokio::runtime::Handle,
	) {
		handle.spawn(async move {
			loop {
				let background_estimate = {
					let mut rpc = rpc_client.lock().await;
					let background_conf_target = serde_json::json!(144);
					let background_estimate_mode = serde_json::json!("ECONOMICAL");
					let resp = rpc
						.call_method::<FeeResponse>(
							"estimatesmartfee",
							&vec![background_conf_target, background_estimate_mode],
						)
						.await
						.unwrap();
					match resp.feerate_sat_per_kw {
						Some(feerate) => std::cmp::max(feerate, MIN_FEERATE),
						None => MIN_FEERATE,
					}
				};

				let normal_estimate = {
					let mut rpc = rpc_client.lock().await;
					let normal_conf_target = serde_json::json!(18);
					let normal_estimate_mode = serde_json::json!("ECONOMICAL");
					let resp = rpc
						.call_method::<FeeResponse>(
							"estimatesmartfee",
							&vec![normal_conf_target, normal_estimate_mode],
						)
						.await
						.unwrap();
					match resp.feerate_sat_per_kw {
						Some(feerate) => std::cmp::max(feerate, MIN_FEERATE),
						None => 2000,
					}
				};

				let high_prio_estimate = {
					let mut rpc = rpc_client.lock().await;
					let high_prio_conf_target = serde_json::json!(6);
					let high_prio_estimate_mode = serde_json::json!("CONSERVATIVE");
					let resp = rpc
						.call_method::<FeeResponse>(
							"estimatesmartfee",
							&vec![high_prio_conf_target, high_prio_estimate_mode],
						)
						.await
						.unwrap();

					match resp.feerate_sat_per_kw {
						Some(feerate) => std::cmp::max(feerate, MIN_FEERATE),
						None => 5000,
					}
				};

				fees.get(&Target::Background)
					.unwrap()
					.store(background_estimate, Ordering::Release);
				fees.get(&Target::Normal).unwrap().store(normal_estimate, Ordering::Release);
				fees.get(&Target::HighPriority)
					.unwrap()
					.store(high_prio_estimate, Ordering::Release);
				tokio::time::sleep(Duration::from_secs(60)).await;
			}
		});
	}

	pub fn get_new_rpc_client(&self) -> std::io::Result<RpcClient> {
		let http_endpoint = HttpEndpoint::for_host(self.host.clone()).with_port(self.port);
		let rpc_credentials =
			base64::encode(format!("{}:{}", self.rpc_user.clone(), self.rpc_password.clone()));
		RpcClient::new(&rpc_credentials, http_endpoint)
	}

	pub async fn create_raw_transaction(&self, outputs: Vec<HashMap<String, f64>>) -> RawTx {
		let mut rpc = self.bitcoind_rpc_client.lock().await;

		let outputs_json = serde_json::json!(outputs);
		rpc.call_method::<RawTx>("createrawtransaction", &vec![serde_json::json!([]), outputs_json])
			.await
			.unwrap()
	}

	pub async fn fund_raw_transaction(&self, raw_tx: RawTx) -> FundedTx {
		let mut rpc = self.bitcoind_rpc_client.lock().await;

		let raw_tx_json = serde_json::json!(raw_tx.0);
		let options = serde_json::json!({
			// LDK gives us feerates in satoshis per KW but Bitcoin Core here expects fees
			// denominated in satoshis per vB. First we need to multiply by 4 to convert weight
			// units to virtual bytes, then divide by 1000 to convert KvB to vB.
			"fee_rate": self.get_est_sat_per_1000_weight(ConfirmationTarget::Normal) as f64 / 250.0,
			// While users could "cancel" a channel open by RBF-bumping and paying back to
			// themselves, we don't allow it here as its easy to have users accidentally RBF bump
			// and pay to the channel funding address, which results in loss of funds. Real
			// LDK-based applications should enable RBF bumping and RBF bump either to a local
			// change address or to a new channel output negotiated with the same node.
			"replaceable": false,
		});
		rpc.call_method("fundrawtransaction", &[raw_tx_json, options]).await.unwrap()
	}

	pub async fn send_raw_transaction(&self, raw_tx: RawTx) {
		let mut rpc = self.bitcoind_rpc_client.lock().await;

		let raw_tx_json = serde_json::json!(raw_tx.0);
		rpc.call_method::<Txid>("sendrawtransaction", &[raw_tx_json]).await.unwrap();
	}

	pub async fn sign_raw_transaction_with_wallet(&self, tx_hex: String) -> SignedTx {
		let mut rpc = self.bitcoind_rpc_client.lock().await;

		let tx_hex_json = serde_json::json!(tx_hex);
		rpc.call_method("signrawtransactionwithwallet", &vec![tx_hex_json]).await.unwrap()
	}

	pub async fn get_new_address(&self) -> Address {
		let mut rpc = self.bitcoind_rpc_client.lock().await;

		let addr_args = vec![serde_json::json!("LDK output address")];
		let addr = rpc.call_method::<NewAddress>("getnewaddress", &addr_args).await.unwrap();
		Address::from_str(addr.0.as_str()).unwrap()
	}

	pub async fn get_blockchain_info(&self) -> BlockchainInfo {
		let mut rpc = self.bitcoind_rpc_client.lock().await;
		rpc.call_method::<BlockchainInfo>("getblockchaininfo", &vec![]).await.unwrap()
	}
}

impl FeeEstimator for BitcoindClient {
	fn get_est_sat_per_1000_weight(&self, confirmation_target: ConfirmationTarget) -> u32 {
		match confirmation_target {
			ConfirmationTarget::Background => {
				self.fees.get(&Target::Background).unwrap().load(Ordering::Acquire)
			}
			ConfirmationTarget::Normal => {
				self.fees.get(&Target::Normal).unwrap().load(Ordering::Acquire)
			}
			ConfirmationTarget::HighPriority => {
				self.fees.get(&Target::HighPriority).unwrap().load(Ordering::Acquire)
			}
		}
	}
}

impl BroadcasterInterface for BitcoindClient {
	fn broadcast_transaction(&self, tx: &Transaction) {
		let bitcoind_rpc_client = self.bitcoind_rpc_client.clone();
		let tx_serialized = serde_json::json!(encode::serialize_hex(tx));
		self.handle.spawn(async move {
			let mut rpc = bitcoind_rpc_client.lock().await;
			// This may error due to RL calling `broadcast_transaction` with the same transaction
			// multiple times, but the error is safe to ignore.
			match rpc.call_method::<Txid>("sendrawtransaction", &vec![tx_serialized]).await {
				Ok(_) => {}
				Err(e) => {
					let err_str = e.get_ref().unwrap().to_string();
					if !err_str.contains("Transaction already in block chain")
						&& !err_str.contains("Inputs missing or spent")
						&& !err_str.contains("bad-txns-inputs-missingorspent")
						&& !err_str.contains("txn-mempool-conflict")
						&& !err_str.contains("non-BIP68-final")
						&& !err_str.contains("insufficient fee, rejecting replacement ")
					{
						panic!("{}", e);
					}
				}
			}
		});
	}
}
