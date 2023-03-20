const { log } = require('console');
const { ethers, newtwork } = require('hardhat')
import { DeployFunction } from "hardhat-deploy/types"
// const { DeployFunction } = require('hardhat-deploy/types')




// module.exports = async () => {

//     const accounts = await ethers.getSigners()
//     const token = await ethers.getContractFactory("Token")
//     console.log(token);
//     const instance = await token.deploy("name","symbol")
//     await instance.deployed()
// }

const deployMocks: DeployFunction = async function () {
    const accounts = await ethers.getSigners()
    console.log(accounts);
    
    const token = await ethers.getContractFactory("Token")
    console.log(token);
    const instance = await token.deploy("name","symbol")
    await instance.deployed()
}

export default deployMocks
deployMocks.tags = ["all", "Token"]