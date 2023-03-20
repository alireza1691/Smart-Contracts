
const { ethers, newtwork } = require('hardhat')





// module.exports = async () => {

//     const accounts = await ethers.getSigners()
//     const token = await ethers.getContractFactory("Token")
//     console.log(token);
//     const instance = await token.deploy("name","symbol")
//     await instance.deployed()
// }

module.exports =  async function () {
    try {
        const accounts = await ethers.getSigners()
        console.log(accounts);
        const account = await ethers.getSigner()
        console.log(account);
        
        const token = await ethers.getContractFactory("Token")
        console.log(token);
        const instance = await token.deploy("name","symbol")
        await instance.deployed()
    } catch (error) {
        console.log(error);
    }
 
}

// export default deployMocks
module.exports.tags = ["all", "Token"]