import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-insight";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";

dotenv.config();

const DEFAULT_COMPILER = {
  version: "0.8.20",
  settings: {
    viaIR: false,
    optimizer: {
      enabled: true,
      runs: 800,
    },
    metadata: {
      // do not include the metadata hash, since this is machine dependent
      // and we want all generated code to be deterministic
      // https://docs.soliditylang.org/en/v0.8.20/metadata.html
      bytecodeHash: "none",
    },
  },
};

const config: HardhatUserConfig = {
  solidity: {
    compilers: [DEFAULT_COMPILER],
  },
  networks: {
    arbitrum: {
      url: `${process.env.ARBITRUM_MAINNET_RPC_URL}`,
      accounts: process.env.ARBITRUM_MAINNET_PRIVATE_KEY !== undefined ? [process.env.ARBITRUM_MAINNET_PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: process.env.ARBITRUM_MAINNET_SCAN_API_KEY,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  gasReporter: {
    enabled: true,
  },
};

export default config;
