// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaguetteToken} from "./BaguetteToken.sol";

/// @title Baguette CTF Distributor
/// @notice Validates CTF flags across multiple contests and rewards winners with fixed-supply Baguette tokens.
contract Baguette {
  error NoFlagsProvided();
  error InvalidContest(uint256 contestId);
  error InvalidChallenge(uint256 contestId, uint256 challengeId);
  error ChallengeAlreadyClaimed(uint256 contestId, uint256 challengeId);
  error InvalidFlag();
  error LeaderboardFull(uint256 contestId);
  error AlreadyWinner(uint256 contestId, address solver);
  error PrizePoolNotFunded(uint256 available, uint256 required);
  error ContestBudgetExceeded(uint256 contestId, uint256 attempted, uint256 maxBudget);

  uint256 public constant MAX_WINNERS = 14;
  uint256 public constant PRIZE_PER_CONTEST = 195_000_000_000_000_000;

  uint256[14] private _prizeSchedule = [
    0.05 ether,
    0.04 ether,
    0.03 ether,
    0.02 ether,
    0.01 ether,
    0.009 ether,
    0.008 ether,
    0.007 ether,
    0.006 ether,
    0.005 ether,
    0.004 ether,
    0.003 ether,
    0.002 ether,
    0.001 ether
  ];

  struct Challenge {
    bytes32 flagHash;
    bool claimed;
  }

  address public owner;
  BaguetteToken public immutable baguetteToken;

  uint256 public prizePoolDeposited;
  uint256 public prizePoolSpent;
  uint256 public nextContestId;

  mapping(uint256 => uint256) public contestPrizeSpent;
  mapping(uint256 => uint256) public contestChallengeCount;
  mapping(uint256 => address[]) private _contestWinners;
  mapping(uint256 => mapping(address => bool)) public contestHasClaimed;
  mapping(uint256 => mapping(uint256 => Challenge)) private _contestChallenges;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event TokenDeployed(address indexed token);
  event ContestStarted(uint256 indexed contestId, uint256 challengeCount);
  event ChallengeRegistered(uint256 indexed contestId, uint256 indexed challengeId, bytes32 flagHash);
  event FlagSolved(
    address indexed solver,
    uint256 indexed contestId,
    uint256 indexed challengeId,
    uint256 placement,
    uint256 prize
  );
  event Withdrawal(address indexed to, uint256 amount, uint256 remainingBudget);

  modifier onlyOwner() {
    require(msg.sender == owner, "Baguette: not owner");
    _;
  }

  constructor(bytes32[] memory initialFlagHashes) {
    owner = msg.sender;
    emit OwnershipTransferred(address(0), msg.sender);

    baguetteToken = new BaguetteToken(address(this));
    emit TokenDeployed(address(baguetteToken));

    prizePoolDeposited = baguetteToken.TOTAL_SUPPLY();
    _createContest(initialFlagHashes);
  }

  function prizeSchedule() external view returns (uint256[14] memory) {
    return _prizeSchedule;
  }

  function totalContests() external view returns (uint256) {
    return nextContestId;
  }

  function contestWinnersLength(uint256 contestId) public view returns (uint256) {
    _requireContestExists(contestId);
    return _contestWinners[contestId].length;
  }

  function contestWinnerAt(uint256 contestId, uint256 index) external view returns (address) {
    _requireContestExists(contestId);
    require(index < _contestWinners[contestId].length, "Baguette: winner out of bounds");
    return _contestWinners[contestId][index];
  }

  function contestWinners(uint256 contestId) external view returns (address[] memory) {
    _requireContestExists(contestId);
    return _contestWinners[contestId];
  }

  function contestPrizeRemaining(uint256 contestId) external view returns (uint256) {
    _requireContestExists(contestId);
    return PRIZE_PER_CONTEST - contestPrizeSpent[contestId];
  }

  function contestChallenge(uint256 contestId, uint256 challengeId) external view returns (bytes32 flagHash, bool claimed) {
    Challenge storage challenge = _getChallenge(contestId, challengeId);
    return (challenge.flagHash, challenge.claimed);
  }

  function startContest(bytes32[] calldata flagHashes) external onlyOwner returns (uint256 contestId) {
    contestId = _createContest(flagHashes);
  }

  function transferOwnership(address newOwner) external onlyOwner {
    require(newOwner != address(0), "Baguette: zero owner");
    address previousOwner = owner;
    owner = newOwner;
    emit OwnershipTransferred(previousOwner, newOwner);
  }

  function submitFlag(
    uint256 contestId,
    uint256 challengeId,
    string calldata flag
  ) external returns (uint256 prize) {
    Challenge storage challenge = _getChallenge(contestId, challengeId);

    if (challenge.claimed) revert ChallengeAlreadyClaimed(contestId, challengeId);
    if (contestHasClaimed[contestId][msg.sender]) revert AlreadyWinner(contestId, msg.sender);
    if (keccak256(abi.encodePacked(flag)) != challenge.flagHash) revert InvalidFlag();

    uint256 placement = _contestWinners[contestId].length;
    if (placement >= MAX_WINNERS) revert LeaderboardFull(contestId);

    prize = _prizeSchedule[placement];
    uint256 available = prizePoolDeposited - prizePoolSpent;
    if (available < prize) revert PrizePoolNotFunded(available, prize);

    uint256 contestSpent = contestPrizeSpent[contestId] + prize;
    if (contestSpent > PRIZE_PER_CONTEST) {
      revert ContestBudgetExceeded(contestId, contestSpent, PRIZE_PER_CONTEST);
    }

    challenge.claimed = true;
    contestHasClaimed[contestId][msg.sender] = true;
    _contestWinners[contestId].push(msg.sender);

    contestPrizeSpent[contestId] = contestSpent;
    prizePoolSpent += prize;

    bool success = baguetteToken.transfer(msg.sender, prize);
    require(success, "Baguette: prize transfer failed");

    emit FlagSolved(msg.sender, contestId, challengeId, placement, prize);
  }

  function withdraw(address to, uint256 amount) external onlyOwner {
    require(to != address(0), "Baguette: invalid recipient");
    uint256 available = prizePoolDeposited - prizePoolSpent;
    require(amount <= available, "Baguette: withdrawal exceeds reserve");

    prizePoolDeposited -= amount;

    bool success = baguetteToken.transfer(to, amount);
    require(success, "Baguette: withdrawal failed");

    emit Withdrawal(to, amount, prizePoolDeposited - prizePoolSpent);
  }

  function _createContest(bytes32[] memory flagHashes) internal returns (uint256 contestId) {
    uint256 length = flagHashes.length;
    if (length == 0) revert NoFlagsProvided();

    contestId = nextContestId++;
    contestChallengeCount[contestId] = length;

    for (uint256 i = 0; i < length; i++) {
      bytes32 flagHash = flagHashes[i];
      require(flagHash != bytes32(0), "Baguette: empty flag hash");
      _contestChallenges[contestId][i] = Challenge({flagHash: flagHash, claimed: false});
      emit ChallengeRegistered(contestId, i, flagHash);
    }

    emit ContestStarted(contestId, length);
  }

  function _requireContestExists(uint256 contestId) internal view {
    if (contestId >= nextContestId) revert InvalidContest(contestId);
  }

  function _getChallenge(uint256 contestId, uint256 challengeId) internal view returns (Challenge storage) {
    _requireContestExists(contestId);

    uint256 totalChallenges = contestChallengeCount[contestId];
    if (challengeId >= totalChallenges) revert InvalidChallenge(contestId, challengeId);

    return _contestChallenges[contestId][challengeId];
  }
}
