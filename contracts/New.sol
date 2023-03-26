// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title A title that should describe the contract/interface
/// @author Alireza Haghshenas
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

contract New is ERC20 {
    constructor(string memory name, string memory symbol) ERC20( name, symbol ) {
        
    }

    function verifySignature(address signer, string memory message, bytes memory sig) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recover(ethSignedMessageHash, sig) == signer;

    }
    function getMessageHash (string memory message) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(message));
    }

    function getEthSignedMessageHash (bytes32 messageHash) public pure returns (bytes32){
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",messageHash));
    }

    function recover(bytes32 ethSignedMessage, bytes memory sig) public pure  returns (address)  {
        (bytes32 r, bytes32 s , uint8 v) = split(sig);
        return ecrecover(ethSignedMessage, v, r, s);

    }

    function split( bytes memory sig) internal pure returns(bytes32 r,bytes32 s,uint8 v) {
        require(sig.length == 65, "invalid length");
        assembly {
            r := mload(add(sig,32))
            s := mload(add(sig,64))
            v := byte(0,mload(add(sig,96)))
        }

    }



}