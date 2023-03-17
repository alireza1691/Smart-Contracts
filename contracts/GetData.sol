// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

/// @title This contract will get balance of ERC20 token of entered address. also can get allowance in the ERC20 contract.
/// @author Alireza Haghshenas
/// @notice This contract is just for learning to develop smart contract and to get balance and allowance there is more simple ways.
/// @dev Explain to a developer any extra details

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC20.sol";

contract GetData {

    constructor() {
        
    }

    function getBalance (address userAddress, address tokenAddress) external view returns(uint256) {
        return IERC20(tokenAddress).balanceOf(userAddress);
    }
    function getAllowance (address owner, address spender, address tokenAddress) external view returns(uint256) {
        return IERC20(tokenAddress).allowance(owner, spender);
    }
    function decreaseAllowance (address tokenAddress, address forAddress,uint256 subtractedValue) external returns(bool){
        (bool ok,) = tokenAddress.delegatecall(abi.encodeWithSignature("decreaseAllowance(address, uint256)",forAddress,subtractedValue));
        return ok;
        // using delegatecall
    }
    function increaseAllowance (address tokenAddress, address forAddress, uint256 addedValue) external returns(bool){
        (bool ok,) = tokenAddress.delegatecall(abi.encodeWithSignature("increaseAllowance(address, uint256)",forAddress,addedValue));
        return ok;
        // using delegatecall
    }
    function transferFrom (address tokenAddress, address from, address to, uint256 amount) external {
        IERC20(tokenAddress).transferFrom(from, to, amount);
    }

}