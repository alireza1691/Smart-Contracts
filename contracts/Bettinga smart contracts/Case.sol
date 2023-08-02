// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "./TransferHelper.sol";
import { Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Admin } from "./Admin.sol";
import { Main } from "./Main.sol";

error Case__NotOwnedByYou();
error Case__InsufficientBalance();
error Case__NotExisted();
error Case__AnswerDoesNotDetermined();

/// @title A Case that is ERC721 smart contract uses as a bet event
/// @author Alireza Haghshenas github: alireza1691
/// @notice This i just one event of betting contains options of betting and each token id points to a ticket. 
/// @dev Each case creates by Admin contract. functions requires 'onlyAdmin' modifier are not called directly
/// They called through the Admin contract



contract Case is ERC721, Ownable{

    event TicketMinted(uint256 indexed tokenId, uint256 amount, uint256 indexed predictedOptionIndex);
    event Claimed(address indexed user, uint256 amount, uint256 indexed tokenId);


    Admin private generator;
    Main private main;

    struct Ticket {
        uint256 amount;
        uint256 selectedOption;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @return Documents the return variables of a contract’s function state variable
    uint256 public tokenIdCounter;
    string[] private optionsName;
    uint256 private answer = 99;
    string private baseURI;
    bool public  isPaused = false;
    mapping (address => uint256) private _balances;
    mapping (uint256 => Ticket) public tokenIdTicket;

    constructor(string memory _name , string memory _symbol,string memory _uri, address _main,string[] memory _optionsName) ERC721(_name, _symbol) {
        baseURI = _uri;
        generator = Admin(msg.sender);
        main = Main(payable(_main));
        optionsName = _optionsName;
    }

    // Require modifiers:
    // To ensure that the answer is attached.
    modifier determined {
        if (answer == 99) {
            revert Case__AnswerDoesNotDetermined();
        }
        _;
    }
    // To ensure if user has enough balance in 'Main' contract.
    modifier requiredBalance (uint256 amount){
        if (main.balance(msg.sender) < amount) {
            revert Case__InsufficientBalance(); 
        }
        _;
    }
    // To ensure that this option is exist.
    modifier requireExist (uint256 index){
        if (optionsName.length <= index) {
            revert Case__NotExisted();
        }
        _;
    }
    // To ensure if tokenId belongs to caller.
    modifier belongCaller (uint256 tokenId){
        if (_ownerOf(tokenId) == _msgSender()){
            _;
        } else {
            revert Case__NotOwnedByYou();
        }
        
    }

    /// @notice Mint ticket to bet on predicted option.
    /// @dev Ticket is a token along its tokenId details of ticked (predicted option and amount to bet on predicted option) will be store as a 'Ticket' structure and store in 'tokenIdTicket' mapping.
    function mintTicket(uint256 amount, uint256 option) external requireExist(option) requiredBalance(amount) {
        require(answer == 99 && isPaused == false, "Betting is not possible now");
        main._useBalance(msg.sender, amount);
        _mint(msg.sender, tokenIdCounter);
        tokenIdTicket[tokenIdCounter] = Ticket(amount, option);
        tokenIdCounter++;
        emit TicketMinted(tokenIdCounter - 1, amount, option);
    }

    /// @notice Getting URI that points an image url
    /// @dev URI of contract and each token are same .Difference of tokens are: amount, predicted option and token id that is owned by a address.
    /// predicted option and amount will be stored in 'Ticket' structure. Also each token will have its token id.
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }


    /// @notice Get each token uri if exists.
    /// @dev As mentioned about prevoius function uri that points to image url for all token are same.
    /// But if ticked with entered tokenId was not exsit, it returns error.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return _baseURI();
    }


    /// @notice Since during the event result prediction may change, we have to pause new betting (pause minting new ticket).
    /// @dev This func called by admin through the 'Admin' contract
    function pauseBetting_ () public onlyOwner {
        require(isPaused == false, "Case already paused");
        isPaused = true;
    }

    /// @notice When result of event determined, the correct answer should attach.
    /// @dev This func called by admin through the 'Admin' contract
    function attachAnswer_ (uint256 answerIndex) external onlyOwner requireExist(answerIndex) {
        require(answer == 99, "Answe already defined");
        require(isPaused == true, "Betting has not paused yet");
        answer = answerIndex;
    }

    /// @notice After attaching answer, user who predicted correct answer will be able to claim their rewards.
    /// @dev Amount of reward depends on the amount bet on each option. Also this amout will be added to their balance in 'Main' contract.
    function claim ( uint256 tokenId ) external determined belongCaller(tokenId){
        require( isEligible(tokenId) == true,"Not eligible!");
        Ticket memory thisTicket = tokenIdTicket[tokenId];
        uint256 betAmount = thisTicket.amount;
        uint256 optionOfTicket = thisTicket.selectedOption;
        (uint256 expectedAmount, uint256 slippage) = calculateReward(betAmount,optionOfTicket);
        _burn(tokenId);
        main.updateIncome(slippage);
        main._transfer( expectedAmount, msg.sender);
        emit Claimed(msg.sender, expectedAmount, tokenId);
    }

    /// @notice This function calculates a reward of each ticket.
    /// @dev This funtion calls by 'claim' function.
    /// @param option is predicted option of ticket.
    /// @param amountOfTicket is the bet amount on mentioned option.
    /// @return expectedAmount is the amount that user will receive.
    /// @return slippage is the amount that is considered to fix slippage and fee of the protocol.
    function calculateReward(uint256 amountOfTicket,uint256 option) view internal returns (uint256 expectedAmount, uint256 slippage) {
         uint256 optionValue = getTicketsValue(option) + amountOfTicket;
        uint256 totalValue = amountOfTicket;
        for (uint i = 0; i < optionsName.length; i++) {
            totalValue += getTicketsValue(i);
        }
        uint256 amountToRatio = (amountOfTicket * totalValue) / optionValue ;
        uint256 profit = amountToRatio - amountOfTicket;
          uint256 profitMinusSlippage = (profit * (optionValue - amountOfTicket)) / optionValue;
          uint256 netProfitOutput = (profitMinusSlippage * (totalValue - optionValue)) / totalValue;
        return ((amountOfTicket + netProfitOutput ), (profit - netProfitOutput)) ;
    }

    /// @notice Burn function to burn tickets that is not eligible to claim reward.
    /// Since user can see owned assets,to prevent confusion it is better to burn tickets that are not eligible after attaching answer.
    function burn(uint256 tokenId) external belongCaller(tokenId){
        _burn(tokenId);
    }

    /// @notice getting total bet amount on each option
    /// @dev We need this data to calculate reward. Also we will show these amounts in UI
    /// @param option is the option that we want to get its total amount.
    function getTicketsValue(uint256 option) view public returns (uint256) {
        uint256 totalOptionAmount;
        for (uint i = 0; i < tokenIdCounter; i++) {
            if (tokenIdTicket[i].selectedOption == option) {
                uint256 thisTicketAmount = tokenIdTicket[i].amount;
                totalOptionAmount += thisTicketAmount;
            }
        } 
        return totalOptionAmount;
    }

    /// @notice Getting answer.
    /// @dev If answer was attached, it should not be 99 anymore and if it returns 99 it means correct answer not attached yet.
    function getAnswer() view public returns (uint256) {
        return answer;
        
    }

    function getImgURI() view external returns(string memory) {
        return _baseURI();
    }

    /// @notice Getting each ticket structure contains amount and predicted option.
    function getTicket(uint256 tokenId) view public returns (Ticket memory) {
        return tokenIdTicket[tokenId];

    }

    /// @notice If answer was determined, this fuction returs elegibilty of reward for each tokenId.
    function isEligible(uint256 tokenId) public view determined returns (bool) {
        if (tokenIdTicket[tokenId].selectedOption == answer) {
            return true;
        } else {
            return false;
        }
    }


    /// @notice To know if betting paused or not
    /// @dev If event was paused (isPaused == true), it will return false means it is not active anymore.
    function isActive() view public returns (bool) {
        return !isPaused;
    }

    /// @notice To get each option name
    /// @dev usecase of this data is  to prevent confusion and showing option names in UI of DApp
    function getOptionsName() view public returns (string[] memory) {
        return optionsName;
    }
}
