// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Case.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TransferHelper } from "./TransferHelper.sol";

/// @title A Contract that manages deposit, withdraw and transfer (of native token).
/// @author Alireza Haghshenas github: alireza1691
/// @notice In order to interact with 'Case's (bet events) it requires balance in this contract.
/// @dev This contract will be deployed by 'Admin' contract. Its address stores in 'Admin' contract and admin can call onlyOnwer functions through the 'Admin' contract.

contract Main is Ownable {

    error Main__InsufficientBalance();
    error Main__NotDefinedCase();

    /// @notice To access and categorize history of balances and transfers, we have 3 events:
    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event ClaimedIncome(uint256 amount);

    /// @notice State variables names are obvious
    uint256 private income;
    address[] private deployedCases;

    /// @notice Balance of each address
    mapping (address => uint256) public balances;


    constructor() {
    }

    /// @notice To ensure if function called by one of 'Case's contract deployed by 'Admin' contract 
    modifier onlyCases {
        bool exists = false;
        for (uint i = 0; i < deployedCases.length; i++) {
            if (deployedCases[i] == _msgSender()) {
                exists = true;
                break;
            }
        }
        if (exists == false) {
            revert Main__NotDefinedCase();
        }
        _;
    }
    /// @notice To ensure if function called by one of 'Case's contract deployed by 'Admin' contract 
    modifier requiredBalance (uint256 amount){
        if (balances[_msgSender()] < amount) {
            revert Main__InsufficientBalance();
        }
        _;
    }

    /// @dev Deposit requires native token and its amount defines as 'msg.value'.
    function deposit() external payable{
        balances[_msgSender()] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    /// @notice Same as 'deposit' it will transfer native token to user using 'safeTransferETH' form 'TransferHelper' library.
    function withdraw(uint256 amount) external requiredBalance(amount){
        balances[_msgSender()] -= amount;
        TransferHelper.safeTransferETH(_msgSender(), amount);
        emit Withdraw(msg.sender, amount);
    }

    /// @notice Use balance to mint ticket in 'Case' contracts.
    /// @dev Explain to a developer any extra details
    function _useBalance(address from, uint256 amount) public onlyCases {
        balances[from] -= amount;
    }

    /// @notice To prevent security risks, instead of transferring reward of eligible tickets, balance of user will increase by calling this function inside 'claim' function through the 'Case' contract.
    /// @dev 'claim' function that calls this function, also burns ticket.
    function _transfer(uint256 amount, address to) public  onlyCases {
        balances[to] += amount;
    }

    /// @notice To access deployed 'Case' contracts by 'Admin' contract onchain, we have to store them and get them using this function.
    /// @dev These deployed cases are requirement of 'onlyCases' modifier.
    function getDeployedCases() view public returns (address[] memory) {
        return deployedCases;
    }

    /// @notice Claim income of protocol. It must called through the 'Admin'c contract
    function claimIncome(uint256 amount,address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
        require(amount <= income, "Insufficient income");
        income -= amount ;
        emit ClaimedIncome(amount);
    }
    /// @notice Add new Case that deployed by 'Admin'.
    function addCase(address newCase) external onlyOwner () {
        deployedCases.push(newCase);
    }
    /// @notice amount of income will update by this function and its called by 'claim' function (claim is function of 'Case' contract).
    function updateIncome(uint256 amount) external onlyCases {
        income += amount;
    }
    /// @notice getter function to get balance of each address.
    function balance(address user) view public returns (uint256) {
        return balances[user];
    }
    /// @notice getter function to get income by contract.
    function getIncome() view public returns (uint256) {
        return income;
    }

    // Sending native token to contract directly, costs 30% of amount.But user can withdraw rest of it using withdraw function.
    receive() external payable {
        balances[msg.sender] += (msg.value * 7) / 10;
        income += (msg.value * 3) / 10;
    }
}
