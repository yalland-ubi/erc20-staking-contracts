/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "./mediators/BasicStakingMediator.sol";
import "./traits/NumericIdCounter.sol";
import "./interfaces/IStakingHomeMediator.sol";
import "./interfaces/IStakingForeignMediator.sol";

contract StakingForeignMediator is IStakingForeignMediator, BasicStakingMediator, NumericIdCounter {
  using SafeMath for uint256;
  using SafeCast for uint256;

  event Lock(address indexed locker, uint256 amount);
  event SlashLocked(address indexed locker, uint256 slashAmount);
  event Stake(
    address indexed delegator,
    uint256 at,
    uint256 amount,
    uint256 balanceAfter,
    uint256 lockedAfter,
    uint256 balanceCacheSlot,
    uint256 totalSupplyCacheSlot
  );
  event Unstake(
    address indexed delegator,
    uint256 at,
    uint256 amount,
    uint256 balanceAfter,
    uint256 unlockedBalanceAfter,
    uint256 balanceCacheSlot,
    uint256 totalSupplyCacheSlot
  );
  event SetCoolDownPeriodLength(uint256 coolDownPeriodLength);
  event SetLockedStakeSlasher(address lockedStakeSlasher);
  event NewCoolDownBox(address indexed delegator, uint256 boxId, uint256 amount, uint64 canBeReleasedSince);
  event ReleaseCoolDownBox(address indexed delegator, uint256 boxId, uint256 amount, uint256 releasedAt);
  event PostLockedStake(bytes32 indexed messageId, address indexed delegator, uint256 value);
  event PostCachedBalance(bytes32 indexed messageId, address indexed delegator, uint256 indexed at);
  event SetStakingToken(address stakingToken);

  struct CoolDownBox {
    address holder;
    bool released;
    uint256 amount;
    uint64 canBeReleasedSince;
    uint64 releasedAt;
  }

  IERC20 public stakingToken;
  uint256 public coolDownPeriodLength;
  address public lockedStakeSlasher;

  uint256 public totalSupply;
  uint256 public totalLocked;
  uint256 public totalUnlocked;
  mapping(address => uint256) internal _balances;
  mapping(address => uint256) internal _unlockedBalances;
  mapping(address => uint256) internal _lockedBalances;

  // ID => details
  mapping(uint256 => CoolDownBox) public coolDownBoxes;

  function initialize(
    address __bridgeContract,
    address __mediatorContractOnOtherSide,
    address __stakingTokenContract,
    uint256 __requestGasLimit,
    uint256 __oppositeChainId,
    uint256 __coolDownPeriodLength,
    address __owner
  ) external initializer {
    _setCoolDownPeriodLength(__coolDownPeriodLength);
    _setStakingToken(__stakingTokenContract);

    _initialize(__bridgeContract, __mediatorContractOnOtherSide, __requestGasLimit, __oppositeChainId, __owner);
  }

  // OWNER INTERFACE

  function setCoolDownPeriodLength(uint256 __coolDownPeriodLength) external onlyOwner {
    _setCoolDownPeriodLength(__coolDownPeriodLength);
  }

  function setLockedStakeSlasher(address __lockedStakeSlasher) external onlyOwner {
    lockedStakeSlasher = __lockedStakeSlasher;

    emit SetLockedStakeSlasher(__lockedStakeSlasher);
  }

  // DELEGATOR INTERFACE

  function stake(uint256 __amount) external {
    address to = address(this);
    address from = msg.sender;

    stakingToken.transferFrom(from, to, __amount);

    _applyStake(from, __amount);
    _postCachedBalance(msg.sender, now);
  }

  function unstake(uint256 __amount) external {
    require(
      _unlockedBalances[msg.sender] >= __amount,
      "StakingForeignMediator: Unstake amount exceeds the unlocked balance"
    );

    _applyUnstake(msg.sender, __amount);
    _createCoolDownBox(msg.sender, __amount);
    _postCachedBalance(msg.sender, now);
  }

  function lock(uint256 __amount) external {
    require(_unlockedBalances[msg.sender] >= __amount, "StakingForeignMediator: Lock amount exceeds the balance");

    _unlockedBalances[msg.sender] = _unlockedBalances[msg.sender].sub(__amount);
    _lockedBalances[msg.sender] = _lockedBalances[msg.sender].add(__amount);
    totalUnlocked = totalUnlocked.sub(__amount);
    totalLocked = totalLocked.add(__amount);

    _postLockedStake(msg.sender, __amount);

    emit Lock(msg.sender, __amount);
  }

  function releaseCoolDownBox(uint256 __boxId) external {
    CoolDownBox storage box = coolDownBoxes[__boxId];

    require(now > box.canBeReleasedSince, "StakingForeignMediator: Cannot be released yet");
    require(box.holder == msg.sender, "StakingForeignMediator: Only box holder allowed");
    require(box.released == false, "StakingForeignMediator: The box has been already released");

    box.released = true;

    emit ReleaseCoolDownBox(msg.sender, __boxId, box.amount, now);

    stakingToken.transfer(msg.sender, box.amount);
  }

  // LOCKED_STAKE_SLASHER INTERFACE

  function slashLocked(address __delegator, uint256 __amount) external {
    require(msg.sender == lockedStakeSlasher, "StakingForeignMediator: Only lockedStakeSlasher allowed");

    require(
      _lockedBalances[__delegator] >= __amount,
      "StakingForeignMediator: Slash amount exceeds the locked balance"
    );

    _balances[__delegator] = _balances[__delegator].sub(__amount);
    _lockedBalances[__delegator] = _lockedBalances[__delegator].sub(__amount);
    totalSupply = totalSupply.sub(__amount);
    totalLocked = totalLocked.sub(__amount);

    _createCoolDownBox(msg.sender, __amount);

    emit SlashLocked(__delegator, __amount);

    _postLockedStake(__delegator, __amount);
  }

  // PERMISSIONLESS INTERFACE
  function pushCachedBalance(
    address __delegatorr,
    uint256 __delegatorCacheSlotIndex,
    uint256 __totalSupplyCacheSlotIndex,
    uint256 __at
  ) external {
    Checkpoint storage pushBalance = _cachedBalances[__delegatorr][__delegatorCacheSlotIndex];
    Checkpoint storage pushTotalSupply = _cachedTotalSupply[__totalSupplyCacheSlotIndex];

    require(pushBalance.fromTimestamp == __at, "StakingForeignMediator: Balance invalid timestamp");
    require(pushTotalSupply.fromTimestamp == __at, "StakingForeignMediator: Total supply invalid timestamp");

    require(
      pushBalance.fromTimestamp == pushTotalSupply.fromTimestamp,
      "StakingForeignMediator: Delegator and totalSupply timestamp don't match"
    );

    _postCachedBalance(__delegatorr, __at);
  }

  function postLockedStake(address __delegator) external {
    _postLockedStake(__delegator, _lockedBalances[__delegator]);
  }

  // INTERNAL METHODS

  function _applyStake(address __delegator, uint256 __amount) internal {
    uint256 balanceAfter = _balances[__delegator].add(__amount);
    uint256 unlockedBalanceAfter = _unlockedBalances[__delegator].add(__amount);
    uint256 totalSupplyAfter = totalSupply.add(__amount);
    uint256 totalUnlockedAfter = totalUnlocked.add(__amount);

    _balances[__delegator] = balanceAfter;
    _unlockedBalances[__delegator] = unlockedBalanceAfter;
    totalSupply = totalSupplyAfter;
    totalUnlocked = totalUnlockedAfter;

    _updateValueAtNow(_cachedBalances[__delegator], balanceAfter);
    _updateValueAtNow(_cachedTotalSupply, totalSupplyAfter);

    emit Stake(
      __delegator,
      now,
      __amount,
      balanceAfter,
      unlockedBalanceAfter,
      _cachedBalances[__delegator].length - 1,
      _cachedTotalSupply.length - 1
    );
  }

  function _applyUnstake(address __delegator, uint256 __amount) internal {
    uint256 balanceAfter = _balances[__delegator].sub(__amount);
    uint256 unlockedBalanceAfter = _unlockedBalances[__delegator].sub(__amount);
    uint256 totalSupplyAfter = totalSupply.sub(__amount);
    uint256 totalUnlockedAfter = totalUnlocked.sub(__amount);

    _balances[__delegator] = balanceAfter;
    _unlockedBalances[__delegator] = unlockedBalanceAfter;
    totalSupply = totalSupplyAfter;
    totalUnlocked = totalUnlockedAfter;

    _updateValueAtNow(_cachedBalances[__delegator], balanceAfter);
    _updateValueAtNow(_cachedTotalSupply, totalSupplyAfter);

    emit Unstake(
      __delegator,
      now,
      __amount,
      balanceAfter,
      unlockedBalanceAfter,
      _cachedBalances[__delegator].length - 1,
      _cachedTotalSupply.length - 1
    );
  }

  function _createCoolDownBox(address __beneficiary, uint256 __amount) internal {
    uint256 boxId = _nextCounterId();
    uint64 canBeReleasedSince = (now + coolDownPeriodLength).toUint64();
    require(canBeReleasedSince > now, "StakingForeignMediator: Either overflow or 0 cooldown period");

    coolDownBoxes[boxId] = CoolDownBox({
      holder: __beneficiary,
      amount: __amount,
      released: false,
      canBeReleasedSince: canBeReleasedSince,
      releasedAt: 0
    });

    emit NewCoolDownBox(__beneficiary, boxId, __amount, canBeReleasedSince);
  }

  function _postCachedBalance(address __delegator, uint256 __at) internal {
    bytes4 methodSelector = IStakingHomeMediator(0).setCachedBalance.selector;
    uint256 pushAmount = balanceOfAt(__delegator, __at);
    uint256 pushTotalSupply = totalSupplyAt(__at);
    bytes memory data = abi.encodeWithSelector(methodSelector, __delegator, pushAmount, pushTotalSupply, __at);

    bytes32 messageId = bridgeContract.requireToPassMessage(mediatorContractOnOtherSide, data, requestGasLimit);
    emit PostCachedBalance(messageId, __delegator, __at);
  }

  function _postLockedStake(address __delegator, uint256 __value) internal {
    bytes4 methodSelector = IStakingHomeMediator(0).setLockedStake.selector;
    bytes memory data = abi.encodeWithSelector(methodSelector, __delegator, __value);

    bytes32 messageId = bridgeContract.requireToPassMessage(mediatorContractOnOtherSide, data, requestGasLimit);
    emit PostLockedStake(messageId, __delegator, __value);
  }

  function _setCoolDownPeriodLength(uint256 __coolDownPeriodLength) internal {
    require(__coolDownPeriodLength > 0, "StakingForeignMediator: Unstake amount exceeds the balance");

    coolDownPeriodLength = __coolDownPeriodLength;

    emit SetCoolDownPeriodLength(__coolDownPeriodLength);
  }

  function _setStakingToken(address __stakingToken) internal {
    require(Address.isContract(__stakingToken), "StakingForeignMediator: Address should be a contract");
    stakingToken = IERC20(__stakingToken);

    emit SetStakingToken(__stakingToken);
  }

  // GETTERS

  function balanceOf(address __delegator) external view returns (uint256) {
    return _balances[__delegator];
  }

  function lockedBalanceOf(address __delegator) external view returns (uint256) {
    return _lockedBalances[__delegator];
  }

  function unlockedBalanceOf(address __delegator) external view returns (uint256) {
    return _unlockedBalances[__delegator];
  }

  function balanceCacheLength(address __delegator) external view returns (uint256) {
    return _cachedBalances[__delegator].length;
  }

  function totalSupplyCacheLength() external view returns (uint256) {
    return _cachedTotalSupply.length;
  }

  function balanceRecordAt(address __delegator, uint256 __cacheSlot)
    public
    view
    returns (uint256 timestamp, uint256 value)
  {
    Checkpoint storage checkpoint = _cachedBalances[__delegator][__cacheSlot];
    return (checkpoint.fromTimestamp, checkpoint.value);
  }

  function totalSupplyRecordSlot(uint256 __cacheSlot) public view returns (uint256 timestamp, uint256 value) {
    Checkpoint storage checkpoint = _cachedTotalSupply[__cacheSlot];
    return (checkpoint.fromTimestamp, checkpoint.value);
  }
}
