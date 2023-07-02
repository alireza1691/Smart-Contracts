import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  defaultNetwork: "localhost",
  solidity: "0.8.18",
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8545",
      // accounts: privateKey !== undefined ? [privateKey] : [],
    },
    // polygon_testnet: {
    //   chainId: 80001,
    //   url: polygonTestnetUrl || "",
    //   accounts: privateKey !== undefined ? [privateKey] : [],
    // },
    // polygon_mainnet: {
    //   chainId: 137,
    //   url: polygonMainnetUrl || "",
    //   accounts: privateKey !== undefined ? [privateKey] : [],
    // },
  },

  
};

export default config;
