// SPDX-License-Identifier: MIT
/* Author: Alireza Haghshenas
/ github account : alireza1691
/ this contract store users data , and they can call their data anytime which they want
*/
pragma solidity ^0.8.17;

contract myStorage {

    // We need structure for each user which has string type and uint256 type that can store any kind of data from user

    struct userData {
        uint256 [] userNumber;
        string [] userString;
    }
 
    // We want to get user data form address of user, so we need a mapping:
    mapping(address => userData) usersData;


    // If user want to store number (uint type), should use this function , but can also store number as a string with next function
    function storeNumber(uint256 inputedData) external{
     
        // Call current user(with address) in mapping of usersData and store inputedData in userNumber array which belongs to current user
        userData storage _user = usersData[msg.sender];
        _user.userNumber.push(inputedData);
    }
    // This function store string data types
    function storeString(string memory inputedData) external{
      
         // Call current user(with address) in mapping of usersData and store inputedData in userStructure array which belongs to current user
        userData storage _user = usersData[msg.sender];
        _user.userString.push(inputedData);
    }

    // This function return everything that user stored in contract
    function getMyData() public view returns(uint256[] memory, string[] memory) {
    userData storage _user = usersData[msg.sender];

    return(_user.userNumber, _user.userString);
    }

    // This function return exact stored data with index, for example i can get my second number which i stored in contract by input number "2" or number "3" for thirth one
    function getSpecialDataInNumbers(uint indexInArray) external view returns(uint){
        //  Arrays indexed started with "0", so the first input has "0" index and so on
        //  For example now if i put number "2" and call this function , function return the "thirth" number of array
        //  Thats a bit confusing ,so we need to "-1" the index which user input for call the function
        indexInArray -= 1;
        userData storage _user = usersData[msg.sender];
        return(_user.userNumber[indexInArray]);
    }

    // This function do exact same as last function , but this one retrun from string array
    function getSpecialDataInStrings(uint indexInArray) external view returns(string memory){
        indexInArray -= 1;
        userData storage _user = usersData[msg.sender];
        return(_user.userString[indexInArray]);

    }



}

