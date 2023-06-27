import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import "@appliedblockchain/chainlink-plugins-fund-link";
import "./tasks";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    ganache: {
      url: "http://localhost:7545",
      chainId: 1337,
    },
    hardhat: {
      hardfork: "merge",
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/your-api-key",
        enabled: false,
      },
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    // sepolia: {
    //   url: process.env.SEPOLIA_RPC_URL || "",
    //   accounts: [process.env.PRIVATE_KEY || ""],
    //   saveDeployments: true,
    //   chainId: 11155111,
    // },
    // mainnet: {
    //   url:
    //     process.env.MAINNET_RPC_URL ||
    //     process.env.ALCHEMY_MAINNET_RPC_URL ||
    //     "https://eth-mainnet.alchemyapi.io/v2/your-api-key",
    //   accounts: [process.env.PRIVATE_KEY || ""],
    //   saveDeployments: true,
    //   chainId: 1,
    // },
    // polygon: {
    //   url:
    //     process.env.POLYGON_MAINNET_RPC_URL ||
    //     "https://polygon-mainnet.alchemyapi.io/v2/your-api-key",
    //   accounts: [process.env.PRIVATE_KEY || ""],
    //   saveDeployments: true,
    //   chainId: 137,
    // },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || "Your etherscan API key",
      mainnet: process.env.ETHERSCAN_API_KEY || "Your etherscan API key",
      polygon: process.env.POLYGONSCAN_API_KEY || "Your polygonscan API key",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },
  contractSizer: {
    runOnCompile: false,
    only: ["APIConsumer", "KeepersCounter", "PriceConsumerV3", "RandomNumberConsumer"],
  },
  namedAccounts: {
    deployer: {
      default: 0,
      1: 0,
    },
    feeCollector: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.4.24",
      },
    ],
  },
  mocha: {
    timeout: 200000,
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

export default config;
