// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TransferHelper } from "./TransferHelper.sol";
import { Main } from "./Main.sol";
import { Case } from "./Case.sol";

/// @title Admin contract manage everything must have done by admin instead of calling directly by owner address.
/// @author Alireza Haghshenas github: alireza1691
/// @notice Admin contract manage all we need as admin of protocol includes 'Main' contract and 'Case's
/// @dev Owner of this contract is actual owner. functions who require call by admin must call through this contract.

contract Admin is Ownable {

    /// @notice To access deployed Cases.
    /// @dev usage of this event is offchain access to provide require data in frontend.
    event CaseRequest(address indexed contractAddress,string name, string symbol);
    /// To access All the paused Cases and accomplished cases we emit an event for each.
    event PausedCase(address indexed contractAddress);
    event AccimplishedCase(address indexed contractAddress, uint256 answerIndex);

    Main mainContract ;

    // By initializing this contract,the 'Main' contract is also initialized and its instance stored in 'mainContract'.
    constructor() {
        Main initializedMain = new Main();
         mainContract = Main(initializedMain);
    }

    /// @notice Function to create new Case (bet event) 
    /// @dev It r
    /// @param name is name of contract. Note that to categorize events, silmiar type of events should have same name but symbol is different.
    /// @param symbol points to exact event. For example if there is a footbal match, 'Footbal match' could be name, and 'team1 vs team2' could be symbol.
    /// @param uri that contains image url
    /// @param names is an array of string containing option names for example a football match could have 3 results: team1 win, draw and team 2 win and these three options make 'names' array.
    function createCase(string memory name, string memory symbol, string memory uri, string[] memory names) external onlyOwner {
        Case newCase = new Case(name, symbol, uri, address(mainContract), names);
        Main(mainContract).addCase(address(newCase));
        emit CaseRequest(address(newCase), name, symbol);
    }

    /// @notice Claim income of protocol by admin
    /// @dev Income stored at 'Main' contract. As mentioned 'onlyAdmin' functions must call indirect through this contract.
    function claimIncome(uint256 amount) external onlyOwner {
        Main(mainContract).claimIncome(amount,_msgSender());
    }
    /// @notice Attach answer of case by its address
    /// @param target is address of relevant contract
    /// @param answer is index of 'optionsName' array in 'Case' contract
   function attachAnswerOfCase(address target,uint256 answer) external onlyOwner {
        Case(target).attachAnswer_(answer);
        emit AccimplishedCase(target, answer);
    }

    /// @notice pause a 'Case' contract (pause betting) by its address as 'target.
    /// As we mentioned in 'Case' natspecs usage of pause is to prevent minting new ticket during the event.
    function pause(address target) external onlyOwner {
        Case(target).pauseBetting_();
        emit PausedCase(target);
    }

    /// @notice Getter function to get address of 'Main' contract.
    function getMain() view public returns (address) {
        return address(mainContract);
    }
    
}
