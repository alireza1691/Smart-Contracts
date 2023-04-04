const { log } = require('console');
const { ethers, newtwork, run } = require('hardhat')
const  hre = require ("hardhat")




async function mocks() {
    const accounts = await ethers.getSigners()
    // console.log(accounts);
    
    const token = await ethers.getContractFactory("Token")
    console.log("hello");
    const instance = await token.deploy("name","symbol")
    await instance.deployed()
    console.log(instance.address);
}


mocks().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
// export default mocks
// mocks.tags = ["all", "Token"]