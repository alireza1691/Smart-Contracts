// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title 
 */
contract Prediction_Native is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    AggregatorV3Interface public oracle;

    bool public genesisLockOnce = false;
    bool public genesisStartOnce = false;

    address public adminAddress; // address of the admin
    address public operatorAddress; // address of the operator
    address public keeperAddress; // address of the keeper

    uint256 public bufferSeconds; // number of seconds for valid execution of a prediction round
    uint256 public intervalSeconds; // interval in seconds between two prediction rounds

    uint256 public minBetAmount; // minimum betting amount (denominated in wei)
    uint256 public treasuryFee; // treasury rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public treasuryAmount; // treasury amount that was not claimed

    uint256 public currentEpoch; // current epoch for prediction round

    uint256 public oracleLatestRoundId; // converted from uint80 (Chainlink)
    uint256 public oracleUpdateAllowance; // seconds

    uint256 public constant MAX_TREASURY_FEE = 1000; // 10%

    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    mapping(uint256 => Round) public rounds;
    mapping(address => uint256[]) public userRounds;

    enum Position {
        Bull,
        Bear
    }

    enum RoundStatus {
        NotStarted,
        Started,
        Locked,
        Ended
    }

    struct Round {
        uint256 epoch;
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 endTimestamp;
        int256 lockPrice;
        int256 endPrice;
        uint256 lockOracleId;
        uint256 endOracleId;
        uint256 totalAmount;
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        RoundStatus status;
    }

    struct BetInfo {
        Position position;
        uint256 amount;
        bool claimed; // default false
    }

    event BetBear(address indexed sender, uint256 indexed epoch, uint256 amount);
    event BetBull(address indexed sender, uint256 indexed epoch, uint256 amount);
    event Claim(address indexed sender, uint256 indexed epoch, uint256 amount);
    event EndRound(uint256 indexed epoch, uint256 indexed roundId, int256 price);
    event LockRound(uint256 indexed epoch, uint256 indexed roundId, int256 price);

    event NewAdminAddress(address admin);
    event NewBufferAndIntervalSeconds(uint256 bufferSeconds, uint256 intervalSeconds);
    event NewMinBetAmount(uint256 indexed epoch, uint256 minBetAmount);
    event NewTreasuryFee(uint256 indexed epoch, uint256 treasuryFee);
    event NewOperatorAddress(address operator);
    event NewOracle(address oracle);
    event NewOracleUpdateAllowance(uint256 oracleUpdateAllowance);
    event NewKeeperAddress(address operator);

    event Pause(uint256 indexed epoch);
    event RewardsCalculated(
        uint256 indexed epoch,
        uint256 rewardBaseCalAmount,
        uint256 rewardAmount,
        uint256 treasuryAmount
    );

    event StartRound(uint256 indexed epoch);
    event TokenRecovery(address indexed token, uint256 amount);
    event TreasuryClaim(uint256 amount);
    event Unpause(uint256 indexed epoch);

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Not admin");
        _;
    }

    modifier onlyAdminOrOperatorOrKeeper() {
        require(
            msg.sender == adminAddress ||
                msg.sender == operatorAddress ||
                msg.sender == keeperAddress,
            "Not operator/admin/keeper"
        );
        _;
    }

    modifier onlyKeeperOrOperator() {
        require(
            msg.sender == keeperAddress || msg.sender == operatorAddress,
            "Not keeper/operator"
        );
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    /**
     * @notice Constructor
     * @param _oracleAddress: oracle address
     * @param _adminAddress: admin address
     * @param _operatorAddress: operator address
     * @param _intervalSeconds: number of time within an interval
     * @param _bufferSeconds: buffer of time for resolution of price
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _oracleUpdateAllowance: oracle update allowance
     * @param _treasuryFee: treasury fee (1000 = 10%)
     */
    constructor(
        address _oracleAddress,
        address _adminAddress,
        address _operatorAddress,
        uint256 _intervalSeconds,
        uint256 _bufferSeconds,
        uint256 _minBetAmount,
        uint256 _oracleUpdateAllowance,
        uint256 _treasuryFee
    ) {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");

        oracle = AggregatorV3Interface(_oracleAddress);
        adminAddress = _adminAddress;
        operatorAddress = _operatorAddress;
        intervalSeconds = _intervalSeconds;
        bufferSeconds = _bufferSeconds;
        minBetAmount = _minBetAmount;
        oracleUpdateAllowance = _oracleUpdateAllowance;
        treasuryFee = _treasuryFee;
    }

    /**
     * @notice Start genesis round
     * @dev Callable by keeper or operator
     */
    function genesisStartRound() external whenNotPaused onlyKeeperOrOperator {
        require(!genesisStartOnce, "Can only run genesisStartRound once");

        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisStartOnce = true;
    }

    /**
     * @notice Lock genesis round
     * @dev Callable by keeper or operator
     */
    function genesisLockRound() external whenNotPaused onlyKeeperOrOperator {
        require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
        require(!genesisLockOnce, "Can only run genesisLockRound once");

        (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

        oracleLatestRoundId = uint256(currentRoundId);

        _safeLockRound(currentEpoch, currentRoundId, currentPrice);

        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisLockOnce = true;
    }

    /**
     * @notice Start the next round n, lock price for round n-1, end round n-2
     * @dev Callable by keeper or operator
     */
    function executeRound() external whenNotPaused onlyKeeperOrOperator {
        require(
            genesisStartOnce && genesisLockOnce,
            "Can only run after genesisStartRound and genesisLockRound is triggered"
        );

        (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

        oracleLatestRoundId = uint256(currentRoundId);

        // CurrentEpoch refers to previous round (n-1)
        _safeLockRound(currentEpoch, currentRoundId, currentPrice);
        _safeEndRound(currentEpoch - 1, currentRoundId, currentPrice);
        _calculateRewards(currentEpoch - 1);

        // Increment currentEpoch to current round (n)
        currentEpoch = currentEpoch + 1;
        _safeStartRound(currentEpoch);
    }

    /**
     * @notice Bet bear position
     * @param epoch: epoch
     */
    function betBear(uint256 epoch)
        external
        payable
        whenNotPaused
        nonReentrant
        notContract
    {
        require(epoch == currentEpoch, "Bet is too early/late");
        require(_bettable(epoch), "Round not bettable");
        require(
            msg.value >= minBetAmount,
            "Bet amount must be greater than minBetAmount"
        );
        require(ledger[epoch][msg.sender].amount == 0, "Can only bet once per round");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bearAmount = round.bearAmount + amount;

        // Update user data
        BetInfo storage betInfo = ledger[epoch][msg.sender];
        betInfo.position = Position.Bear;
        betInfo.amount = amount;
        userRounds[msg.sender].push(epoch);

        emit BetBear(msg.sender, epoch, amount);
    }

    /**
     * @notice Bet bull position
     * @param epoch: epoch
     */
    function betBull(uint256 epoch)
        external
        payable
        whenNotPaused
        nonReentrant
        notContract
    {
        require(epoch == currentEpoch, "Bet is too early/late");
        require(_bettable(epoch), "Round not bettable");
        require(
            msg.value >= minBetAmount,
            "Bet amount must be greater than minBetAmount"
        );
        require(ledger[epoch][msg.sender].amount == 0, "Can only bet once per round");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bullAmount = round.bullAmount + amount;

        // Update user data
        BetInfo storage betInfo = ledger[epoch][msg.sender];
        betInfo.position = Position.Bull;
        betInfo.amount = amount;
        userRounds[msg.sender].push(epoch);

        emit BetBull(msg.sender, epoch, amount);
    }

    /**
     * @notice Returns round epochs and bet information for a user that has participated
     * @param user: user address
     * @param cursor: cursor
     * @param size: size
     */
    function getUserRounds(
        address user,
        uint256 cursor,
        uint256 size
    )
        external
        view
        returns (
            uint256[] memory,
            BetInfo[] memory,
            uint256
        )
    {
        uint256 length = size;

        if (length > userRounds[user].length - cursor) {
            length = userRounds[user].length - cursor;
        }

        uint256[] memory values = new uint256[](length);
        BetInfo[] memory betInfo = new BetInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            values[i] = userRounds[user][cursor + i];
            betInfo[i] = ledger[values[i]][user];
        }

        return (values, betInfo, cursor + length);
    }

    /**
     * @notice Returns round epochs length
     * @param user: user address
     */
    function getUserRoundsLength(address user) external view returns (uint256) {
        return userRounds[user].length;
    }

    /**
     * @notice Claim reward for an array of epochs
     * @param epochs: array of epochs
     */
    function claim(uint256[] calldata epochs) external nonReentrant notContract {
        uint256 reward; // Initializes reward

        for (uint256 i = 0; i < epochs.length; i++) {
            require(
                rounds[epochs[i]].status != RoundStatus.NotStarted,
                "Round has not started"
            );

            uint256 addedReward = 0;

            // Round valid, claim rewards
            if (rounds[epochs[i]].status == RoundStatus.Ended) {
                require(claimable(epochs[i], msg.sender), "Not eligible for claim");
                Round memory round = rounds[epochs[i]];
                addedReward =
                    (ledger[epochs[i]][msg.sender].amount * round.rewardAmount) /
                    round.rewardBaseCalAmount;
            }
            // Round invalid, refund bet amount
            else {
                require(refundable(epochs[i], msg.sender), "Not eligible for refund");
                addedReward = ledger[epochs[i]][msg.sender].amount;
            }

            ledger[epochs[i]][msg.sender].claimed = true;
            reward += addedReward;

            emit Claim(msg.sender, epochs[i], addedReward);
        }

        if (reward > 0) {
            _safeTransferNativeCoin(address(msg.sender), reward);
        }
    }

    /**
     * @notice Get the claimable stats of specific epoch and user account
     * @param epoch: epoch
     * @param user: user address
     */
    function claimable(uint256 epoch, address user) public view returns (bool) {
        BetInfo memory betInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        if (round.lockPrice == round.endPrice) {
            return false;
        }
        return
            round.status == RoundStatus.Ended &&
            betInfo.amount != 0 &&
            !betInfo.claimed &&
            ((round.endPrice > round.lockPrice && betInfo.position == Position.Bull) ||
                (round.endPrice < round.lockPrice &&
                    betInfo.position == Position.Bear));
    }

    /**
     * @notice Get the refundable stats of specific epoch and user account
     * @param epoch: epoch
     * @param user: user address
     */
    function refundable(uint256 epoch, address user) public view returns (bool) {
        BetInfo memory betInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        return
            betInfo.amount != 0 &&
            !betInfo.claimed &&
            ((round.status == RoundStatus.Started &&
                block.timestamp > round.lockTimestamp + bufferSeconds) ||
                (round.status == RoundStatus.Locked &&
                    block.timestamp > round.endTimestamp + bufferSeconds));
    }

    /**
     * @notice called by the admin to pause, triggers stopped state
     * @dev Callable by admin or operator
     */
    function pause() external whenNotPaused onlyAdminOrOperatorOrKeeper {
        _pause();

        emit Pause(currentEpoch);
    }

    /**
     * @notice called by the admin to unpause, returns to normal state
     * Reset genesis state. Once paused, the rounds would need to be kickstarted by genesis
     * @dev Callable by admin or operator or keeper
     */
    function unpause() external whenPaused onlyAdminOrOperatorOrKeeper {
        genesisStartOnce = false;
        genesisLockOnce = false;
        _unpause();

        emit Unpause(currentEpoch);
    }

    /**
     * @notice Claim all rewards in treasury
     * @dev Callable by admin
     */
    function claimTreasury() external nonReentrant onlyAdmin {
        uint256 currentTreasuryAmount = treasuryAmount;
        treasuryAmount = 0;
        _safeTransferNativeCoin(adminAddress, currentTreasuryAmount);

        emit TreasuryClaim(currentTreasuryAmount);
    }

    /**
     * @notice Set buffer and interval (in seconds)
     * @dev Callable by admin
     */
    function setBufferAndIntervalSeconds(
        uint256 _bufferSeconds,
        uint256 _intervalSeconds
    ) external whenPaused onlyAdmin {
        require(
            _bufferSeconds < _intervalSeconds,
            "bufferSeconds must be less than intervalSeconds"
        );
        bufferSeconds = _bufferSeconds;
        intervalSeconds = _intervalSeconds;

        emit NewBufferAndIntervalSeconds(_bufferSeconds, _intervalSeconds);
    }

    /**
     * @notice Set minBetAmount
     * @dev Callable by admin
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount != 0, "Must be greater than 0");
        minBetAmount = _minBetAmount;

        emit NewMinBetAmount(currentEpoch, minBetAmount);
    }

    /**
     * @notice Set operator address
     * @dev Callable by admin
     */
    function setOperator(address _operatorAddress) external onlyAdmin {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;

        emit NewOperatorAddress(_operatorAddress);
    }

    /**
     * @notice Set keeper address
     * @dev Callable by admin
     */
    function setKeeper(address _keeperAddress) external onlyAdmin {
        require(_keeperAddress != address(0), "Cannot be zero address");
        keeperAddress = _keeperAddress;

        emit NewKeeperAddress(_keeperAddress);
    }

    /**
     * @notice Set Oracle address
     * @dev Callable by admin
     */
    function setOracle(address _oracle) external whenPaused onlyAdmin {
        require(_oracle != address(0), "Cannot be zero address");
        oracleLatestRoundId = 0;
        oracle = AggregatorV3Interface(_oracle);

        // Dummy check to make sure the interface implements this function properly
        oracle.latestRoundData();

        emit NewOracle(_oracle);
    }

    /**
     * @notice Set oracle update allowance
     * @dev Callable by admin
     */
    function setOracleUpdateAllowance(uint256 _oracleUpdateAllowance)
        external
        whenPaused
        onlyAdmin
    {
        oracleUpdateAllowance = _oracleUpdateAllowance;

        emit NewOracleUpdateAllowance(_oracleUpdateAllowance);
    }

    /**
     * @notice Set treasury fee
     * @dev Callable by admin
     */
    function setTreasuryFee(uint256 _treasuryFee) external whenPaused onlyAdmin {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");
        treasuryFee = _treasuryFee;

        emit NewTreasuryFee(currentEpoch, treasuryFee);
    }

    /**
     * @notice It allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @param _amount: token amount
     * @dev Callable by owner
     */
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);

        emit TokenRecovery(_token, _amount);
    }

    /**
     * @notice Set admin address
     * @dev Callable by owner
     */
    function setAdmin(address _adminAddress) external onlyOwner {
        require(_adminAddress != address(0), "Cannot be zero address");
        adminAddress = _adminAddress;

        emit NewAdminAddress(_adminAddress);
    }

    /**
     * @notice Calculate rewards for round
     * @param epoch: epoch
     */
    function _calculateRewards(uint256 epoch) internal {
        require(rounds[epoch].status == RoundStatus.Ended, "Round is not ended");
        require(
            rounds[epoch].rewardBaseCalAmount == 0 && rounds[epoch].rewardAmount == 0,
            "Rewards calculated"
        );
        Round storage round = rounds[epoch];
        uint256 rewardBaseCalAmount;
        uint256 treasuryAmt;
        uint256 rewardAmount;

        // Bull wins
        if (round.endPrice > round.lockPrice) {
            rewardBaseCalAmount = round.bullAmount;
            //no winner , house win
            if (rewardBaseCalAmount == 0) {
                treasuryAmt = round.totalAmount;
            } else {
                treasuryAmt = (round.totalAmount * treasuryFee) / 10000;
            }
            rewardAmount = round.totalAmount - treasuryAmt;
        }
        // Bear wins
        else if (round.endPrice < round.lockPrice) {
            rewardBaseCalAmount = round.bearAmount;
            //no winner , house win
            if (rewardBaseCalAmount == 0) {
                treasuryAmt = round.totalAmount;
            } else {
                treasuryAmt = (round.totalAmount * treasuryFee) / 10000;
            }
            rewardAmount = round.totalAmount - treasuryAmt;
        }
        // House wins
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
            treasuryAmt = round.totalAmount;
        }
        round.rewardBaseCalAmount = rewardBaseCalAmount;
        round.rewardAmount = rewardAmount;

        // Add to treasury
        treasuryAmount += treasuryAmt;

        emit RewardsCalculated(epoch, rewardBaseCalAmount, rewardAmount, treasuryAmt);
    }

    /**
     * @notice End round
     * @param epoch: epoch
     * @param roundId: roundId
     * @param price: price of the round
     */
    function _safeEndRound(
        uint256 epoch,
        uint256 roundId,
        int256 price
    ) internal {
        require(
            rounds[epoch].status == RoundStatus.Locked,
            "Round can be ended only after round has locked"
        );
        require(
            block.timestamp >= rounds[epoch].endTimestamp,
            "Round can be ended only after endTimestamp"
        );
        require(
            block.timestamp <= rounds[epoch].endTimestamp + bufferSeconds,
            "Round can be ended only within bufferSeconds"
        );
        Round storage round = rounds[epoch];
        round.endPrice = price;
        round.endOracleId = roundId;
        round.status = RoundStatus.Ended;

        emit EndRound(epoch, roundId, round.endPrice);
    }

    /**
     * @notice Lock round
     * @param epoch: epoch
     * @param roundId: roundId
     * @param price: price of the round
     */
    function _safeLockRound(
        uint256 epoch,
        uint256 roundId,
        int256 price
    ) internal {
        require(
            rounds[epoch].status == RoundStatus.Started,
            "Round can be locked only after round has started"
        );
        require(
            block.timestamp >= rounds[epoch].lockTimestamp,
            "Round can be locked only after lockTimestamp"
        );
        require(
            block.timestamp <= rounds[epoch].lockTimestamp + bufferSeconds,
            "Round can be locked only within bufferSeconds"
        );
        Round storage round = rounds[epoch];
        round.endTimestamp = block.timestamp + intervalSeconds;
        round.lockPrice = price;
        round.lockOracleId = roundId;
        round.status = RoundStatus.Locked;

        emit LockRound(epoch, roundId, round.lockPrice);
    }

    /**
     * @notice Start round
     * Previous round n-2 must end
     * @param epoch: epoch
     */
    function _safeStartRound(uint256 epoch) internal {
        require(
            rounds[epoch].status == RoundStatus.NotStarted,
            "Round can be started only once"
        );
        require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
        require(
            rounds[epoch - 2].endTimestamp != 0,
            "Round can be start only after round n-2 has ended"
        );
        require(
            block.timestamp >= rounds[epoch - 2].endTimestamp,
            "New round can start only after round n-2 endTimestamp"
        );
        _startRound(epoch);
    }

    /**
     * @notice Transfer native coin in a safe way
     * @param to: address to transfer coin to
     * @param value: coin amount to transfer (in wei)
     */
    function _safeTransferNativeCoin(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: NATIVE_COIN_TRANSFER_FAILED");
    }

    /**
     * @notice Start round
     * @param epoch: epoch
     */
    function _startRound(uint256 epoch) internal {
        Round storage round = rounds[epoch];
        round.startTimestamp = block.timestamp;
        round.lockTimestamp = block.timestamp + intervalSeconds;
        round.endTimestamp = block.timestamp + (2 * intervalSeconds);
        round.epoch = epoch;
        round.totalAmount = 0;
        round.status = RoundStatus.Started;

        emit StartRound(epoch);
    }

    /**
     * @notice Determine if a round is valid for receiving bets
     * Round must have started and locked
     * Current timestamp must be within startTimestamp and endTimestamp
     */
    function _bettable(uint256 epoch) internal view returns (bool) {
        return
            rounds[epoch].status == RoundStatus.Started &&
            rounds[epoch].startTimestamp != 0 &&
            rounds[epoch].lockTimestamp != 0 &&
            block.timestamp > rounds[epoch].startTimestamp &&
            block.timestamp < rounds[epoch].lockTimestamp;
    }

    /**
     * @notice Get latest recorded price from oracle
     * If it falls below allowed buffer or has not updated, it would be invalid.
     * The timestamp of the Oracle update is not necessarily the same as the timestamp of the block in which it is recorded, and can be greater than that.
     */
    function _getPriceFromOracle() internal view returns (uint80, int256) {
        uint256 leastAllowedTimestamp = block.timestamp + oracleUpdateAllowance;
        (uint80 roundId, int256 price, , uint256 timestamp, ) = oracle
            .latestRoundData();
        require(
            timestamp <= leastAllowedTimestamp,
            "Oracle update exceeded max timestamp allowance"
        );
        require(
            uint256(roundId) > oracleLatestRoundId,
            "Oracle update roundId must be larger than oracleLatestRoundId"
        );
        return (roundId, price);
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}