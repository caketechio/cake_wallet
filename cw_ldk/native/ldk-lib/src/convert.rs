use bitcoin::hashes::hex::FromHex;
use bitcoin::BlockHash;
use lightning_block_sync::http::JsonResponse;
use std::convert::TryInto;

pub struct FundedTx {
	pub changepos: i64,
	pub hex: String,
}

impl TryInto<FundedTx> for JsonResponse {
	type Error = std::io::Error;
	fn try_into(self) -> std::io::Result<FundedTx> {
		Ok(FundedTx {
			changepos: self.0["changepos"].as_i64().unwrap(),
			hex: self.0["hex"].as_str().unwrap().to_string(),
		})
	}
}

pub struct RawTx(pub String);

impl TryInto<RawTx> for JsonResponse {
	type Error = std::io::Error;
	fn try_into(self) -> std::io::Result<RawTx> {
		Ok(RawTx(self.0.as_str().unwrap().to_string()))
	}
}

pub struct SignedTx {
	pub complete: bool,
	pub hex: String,
}

impl TryInto<SignedTx> for JsonResponse {
	type Error = std::io::Error;
	fn try_into(self) -> std::io::Result<SignedTx> {
		Ok(SignedTx {
			hex: self.0["hex"].as_str().unwrap().to_string(),
			complete: self.0["complete"].as_bool().unwrap(),
		})
	}
}

pub struct NewAddress(pub String);
impl TryInto<NewAddress> for JsonResponse {
	type Error = std::io::Error;
	fn try_into(self) -> std::io::Result<NewAddress> {
		Ok(NewAddress(self.0.as_str().unwrap().to_string()))
	}
}

pub struct FeeResponse {
	pub feerate_sat_per_kw: Option<u32>,
	pub errored: bool,
}

impl TryInto<FeeResponse> for JsonResponse {
	type Error = std::io::Error;
	fn try_into(self) -> std::io::Result<FeeResponse> {
		let errored = !self.0["errors"].is_null();
		Ok(FeeResponse {
			errored,
			feerate_sat_per_kw: match self.0["feerate"].as_f64() {
				// Bitcoin Core gives us a feerate in BTC/KvB, which we need to convert to
				// satoshis/KW. Thus, we first multiply by 10^8 to get satoshis, then divide by 4
				// to convert virtual-bytes into weight units.
				Some(feerate_btc_per_kvbyte) => {
					Some((feerate_btc_per_kvbyte * 100_000_000.0 / 4.0).round() as u32)
				}
				None => None,
			},
		})
	}
}

pub struct BlockchainInfo {
	pub latest_height: usize,
	pub latest_blockhash: BlockHash,
	pub chain: String,
}

impl TryInto<BlockchainInfo> for JsonResponse {
	type Error = std::io::Error;
	fn try_into(self) -> std::io::Result<BlockchainInfo> {
		Ok(BlockchainInfo {
			latest_height: self.0["blocks"].as_u64().unwrap() as usize,
			latest_blockhash: BlockHash::from_hex(self.0["bestblockhash"].as_str().unwrap())
				.unwrap(),
			chain: self.0["chain"].as_str().unwrap().to_string(),
		})
	}
}
