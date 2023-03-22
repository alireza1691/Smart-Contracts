import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types"
import { Module } from "module";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import hre from "hardhat";
// import { HardhatEthersHelpers } from "@nomiclabs/hardhat-ethers/dist/src/types";

// const wrapHre = hre as HardhatRuntimeEnvironment & { ethers: any } & {
//   ethers: typeof ethers ;
// };

const main: DeployFunction = async function(){

  const addresses = await ethers.getSigners()
  console.log(addresses[0]);
  
 
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy("name","symbol");

  await token.deployed();

  console.log(token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
export default main;