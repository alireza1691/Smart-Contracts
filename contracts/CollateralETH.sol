// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

contract CollateralETH {

    constructor() {
        
    }
    uint256 counter;
    struct Collateral {
        uint256 value;
        address owner;
        address spender;
        address witness;
    }
    mapping (uint256 => Collateral) public counterToCollateral;
    mapping (uint256 => uint) public votes;


    function deposit(address spender, address witness) external payable returns(uint256){
        Collateral memory newCollateral = Collateral(msg.value,msg.sender,spender,witness);
        counterToCollateral[counter]= newCollateral;
        counter ++;
        return(counter-1);
    }

    function vote(uint256 number) external {
        require(msg.sender == counterToCollateral[number].owner ||
        msg.sender == counterToCollateral[number].spender ||
        msg.sender == counterToCollateral[number].witness ,"Not allowed to vote");
        votes[number] ++;
    }

    function withdraw(uint256 number) external payable returns(bool){
        Collateral memory thisCollateral = counterToCollateral[number];
        require(msg.sender == thisCollateral.spender,"Not spender");
        require(votes[number] >= 2,"Not enough votes");
        uint256 withdrawableAmount = thisCollateral.value;
        thisCollateral.value = 0;
        (bool ok,) = msg.sender.call{value: withdrawableAmount}("");
        return ok;
    }
}