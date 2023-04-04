import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types"
import { Module } from "module";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import hre from "hardhat";
// import { HardhatEthersHelpers } from "@nomiclabs/hardhat-ethers/dist/src/types";

// const wrapHre = hre as HardhatRuntimeEnvironment & { ethers: any } & {
//   ethers: typeof ethers ;
// };


async function main() {
    const accounts = await ethers.getSigners()
    // console.log(accounts);
    const signer = accounts[0]
    
    const test = await ethers.getContractFactory("TestSignature")
    const instance = await test.deploy("name","symbol")
    await instance.deployed()
    console.log(instance.address);

    const messageHash = await instance.getMessageHash("hey")
    const sig = await signer.signMessage(ethers.utils.arrayify(messageHash))

    const verify = await instance.verifySignature(signer.address,"hey",sig)
    console.log(verify);
    
    
  }
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  