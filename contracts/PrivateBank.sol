// SPDX-License-Identifier: MIT

/// @title A contract for deposit ETH and withdraw it no tracking possibility
/// @author Alireza Haghshenas
/// @notice For better Functionality we recommended withdraw your ETH through several steps.
/// @dev Explain to a developer any extra details

pragma solidity ^0.8.17;

library PrivLib {

    function _calculate (uint256 balance) internal pure returns(uint256 amount) {
        for (uint i = 20; i >= 15; i--) {
            if ((balance / 10**i) >= 1) {
                if ((balance / 10**i) >= 5) {
                    return 50**i;
                }
                return 10**i;
            }
        }
    }
}

library StorageLib {

    struct Variables {
        address owner;
        uint256 minimumAmount;
        uint256 fee;
        uint256 income;
        mapping (address => uint256) balances;
    }

    function getSlot (bytes32 slot) internal pure returns(Variables storage v){
        assembly {
            v.slot := slot
        }
    }
}

error BlackWhole__insufficientBalance();
error BlackWhole__lessThanMinimum();
error BlackWhole__notOwner();

contract PrivateBank {

    using PrivLib for uint256;
    
    address payable private immutable owner;
    uint256 private minimumAmount; // Minimum amount for deposit in contract
    uint256 private fee = 1; // Fee in percent, for calculating fee: totalAmountOfTx * fee / 100
    mapping (address => uint256) private balances; // Balance of each address
    uint256 private income; // Total fee amount which belongs to contract and owner can withdraw it.

    // A modifier which revert function if msg.sender does not equal to owner:
    modifier onlyOwner {
        if (msg.sender == owner) {
            _;
        }
        revert BlackWhole__notOwner();
    }

    // Whoever create contract will be owner:
    constructor() {
        owner = payable(msg.sender);
    }

    // Deposit ETH in contract an increase balances of 'to' address as much as: msg.value
    // Note that user just can deposit specific amounts (0.01 , 0.05 , 0.1 , 0.5 , 1 , 5 , 10 ,50 , 100 ETH ), also it is also the same for withdraw.
    function deposit (address to) payable external {
        require(msg.value == 1e16 || msg.value == 5e16||msg.value ==1e17||msg.value ==5e17||msg.value ==1e18||msg.value ==5e18||msg.value ==1e19||msg.value ==5e19||msg.value ==1e20||msg.value ==5e20,"This amount not allowed");
        // Entered value should be at least 0.01 ETH, otherwise the transaction will be reverted.
        if (msg.value < minimumAmount ) {
            revert BlackWhole__lessThanMinimum();
        }
        balances[to] = msg.value;
    }

    // Users can withdraw amount if they have deposited to a address before. 
    // Note that try to withdraw through couple times. for example if you deposited 10 ETH, its better to withdraw with this values : 5 ETH , 5 ETH or trough more functions like that: 5 ETH , 1 ETH , 1 ETH , 1 ETH , 1 ETH , 1 ETH
    // It's better for security, but if you want, you can withdraw it once.
    // Same as deposit withdraw amount should be like the mentioned numbers, if user enter other amount for example 5.5 ETH, countract will calculate and send 5 ETH 
    function withdraw (uint256 amount) payable external {
        uint256 userBalance = balances[msg.sender];
        if (userBalance < amount) {
            revert BlackWhole__insufficientBalance();
        }
        uint256 withdrawable = amount._calculate();
        balances[msg.sender] -= withdrawable;
        (bool ok,) = msg.sender.call{value: (withdrawable*(100-fee))/100 }("");
        if (ok) {
            income += (withdrawable*fee)/100;
        }
    }

    // This function calculate how much ETH sould send to user, depends on entered 'amount' in 'withdraw' function.
    

    // Getter function will be deleted before deploy on mainnet
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // Withdraw fee for owner
    // Instead of using income variable we can using balance of owner through the mapping.
    function withdrawFee(uint256 amount) external payable onlyOwner{
        if (amount > income) {
            revert BlackWhole__insufficientBalance();
        }
        (bool ok,) = msg.sender.call{value:income}("");
        if (ok) {
            income -= amount;
        }
    }


    function testStorage() external view returns(uint256){
        bytes32 convertedString = keccak256("testText");
        return StorageLib.getSlot(convertedString).fee;
    }

}