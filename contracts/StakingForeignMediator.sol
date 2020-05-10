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

  event Stake(
    address indexed delegate,
    uint256 at,
    uint256 amount,
    uint256 balanceBefore,
    uint256 balanceAfter,
    uint256 balanceCacheSlot,
    uint256 totalSupplyCacheSlot
  );
  event Unstake(
    address indexed delegate,
    uint256 at,
    uint256 amount,
    uint256 balanceBefore,
    uint256 balanceAfter,
    uint256 balanceCacheSlot,
    uint256 totalSupplyCacheSlot
  );
  event NewCoolDownBox(address indexed delegator, uint256 boxId, uint256 amount, uint64 canBeReleasedSince);
  event ReleaseCoolDownBox(address indexed delegator, uint256 boxId, uint256 amount, uint256 releasedAt);
  event SetYSTToken(address token);

  struct CoolDownBox {
    address holder;
    bool released;
    uint256 amount;
    uint64 canBeReleasedSince;
    uint64 releasedAt;
  }

  IERC20 public stakingToken;
  uint256 public coolDownPeriodLength;

  uint256 public totalSupply;
  mapping(address => uint256) internal _balances;
  // ID => details
  mapping(uint256 => CoolDownBox) public coolDownBoxes;

  function initialize(
    address _bridgeContract,
    address _mediatorContractOnOtherSide,
    address _stakingTokenContract,
    uint256 _requestGasLimit,
    uint256 _oppositeChainId,
    uint256 _coolDownPeriodLength,
    address _owner
  ) external initializer {
    _setCoolDownPeriodLength(_coolDownPeriodLength);
    _setYSTToken(_stakingTokenContract);

    _initialize(_bridgeContract, _mediatorContractOnOtherSide, _requestGasLimit, _oppositeChainId, _owner);
  }

  // OWNER INTERFACE

  function setCoolDownPeriodLength(uint256 _coolDownPeriodLength) external onlyOwner {
    _setCoolDownPeriodLength(_coolDownPeriodLength);
  }

  // DELEGATE INTERFACE

  function stake(uint256 _amount) external {
    address to = address(this);
    address from = msg.sender;

    stakingToken.transferFrom(from, to, _amount);

    _applyStake(from, _amount);
    _postCachedBalance(msg.sender, now);
  }

  function unstake(uint256 _amount) external {
    require(_balances[msg.sender] >= _amount, "StakingForeignMediator: unstake amount exceeds the balance");

    _applyUnstake(msg.sender, _amount);

    uint256 boxId = _nextCounterId();
    uint64 canBeReleasedSince = (now + coolDownPeriodLength).toUint64();
    require(canBeReleasedSince > now, "StakingForeignMediator: either overflow or 0 cooldown period");

    coolDownBoxes[boxId] = CoolDownBox({
      holder: msg.sender,
      amount: _amount,
      released: false,
      canBeReleasedSince: canBeReleasedSince,
      releasedAt: 0
    });

    emit NewCoolDownBox(msg.sender, boxId, _amount, canBeReleasedSince);

    _postCachedBalance(msg.sender, now);
  }

  function pushCachedBalance(
    address __delegate,
    uint256 __delegateCacheSlotIndex,
    uint256 __totalSupplyCacheSlotIndex,
    uint256 __at
  ) external {
    Checkpoint storage pushBalance = _cachedBalances[__delegate][__delegateCacheSlotIndex];
    Checkpoint storage pushTotalSupply = _cachedTotalSupply[__totalSupplyCacheSlotIndex];

    require(pushBalance.fromTimestamp == __at, "StakingForeignMediator: balance invalid timestamp");
    require(pushTotalSupply.fromTimestamp == __at, "StakingForeignMediator: total supply invalid timestamp");

    require(
      pushBalance.fromTimestamp == pushTotalSupply.fromTimestamp,
      "StakingForeignMediator: delegate and totalSupply timestamp don't match"
    );

    _postCachedBalance(__delegate, __at);
  }

  function releaseCoolDownBox(uint256 _boxId) external {
    CoolDownBox storage box = coolDownBoxes[_boxId];

    require(now > box.canBeReleasedSince, "StakingForeignMediator: cannot be released yet");
    require(box.holder == msg.sender, "StakingForeignMediator: only box holder allowed");
    require(box.released == false, "StakingForeignMediator: the box has been already released");

    box.released = true;

    emit ReleaseCoolDownBox(msg.sender, _boxId, box.amount, now);

    stakingToken.transfer(msg.sender, box.amount);
  }

  // INTERNAL METHODS

  function _applyStake(address _delegate, uint256 _amount) internal {
    uint256 balanceBefore = _balances[_delegate];
    uint256 balanceAfter = balanceBefore.add(_amount);
    uint256 totalSupplyAfter = totalSupply.add(_amount);

    _balances[_delegate] = balanceAfter;
    totalSupply = totalSupplyAfter;

    _updateValueAtNow(_cachedBalances[_delegate], balanceAfter);
    _updateValueAtNow(_cachedTotalSupply, totalSupplyAfter);

    emit Stake(
      _delegate,
      now,
      _amount,
      balanceBefore,
      balanceAfter,
      _cachedBalances[_delegate].length - 1,
      _cachedTotalSupply.length - 1
    );
  }

  function _applyUnstake(address _delegate, uint256 _amount) internal {
    uint256 balanceBefore = _balances[_delegate];
    uint256 balanceAfter = balanceBefore.sub(_amount);
    uint256 totalSupplyAfter = totalSupply.sub(_amount);

    _balances[_delegate] = balanceAfter;
    totalSupply = totalSupplyAfter;

    _updateValueAtNow(_cachedBalances[_delegate], balanceAfter);
    _updateValueAtNow(_cachedTotalSupply, totalSupplyAfter);

    emit Unstake(
      _delegate,
      now,
      _amount,
      balanceBefore,
      balanceAfter,
      _cachedBalances[_delegate].length - 1,
      _cachedTotalSupply.length - 1
    );
  }

  function _postCachedBalance(address __delegate, uint256 __at) internal {
    bytes4 methodSelector = IStakingHomeMediator(0).setCachedBalance.selector;
    uint256 pushAmount = balanceOfAt(__delegate, __at);
    uint256 pushTotalSupply = totalSupplyAt(__at);

    bytes memory data = abi.encodeWithSelector(methodSelector, __delegate, pushAmount, pushTotalSupply, __at);

    bytes32 dataHash = keccak256(data);
    _setNonce(dataHash);

    bridgeContract.requireToPassMessage(mediatorContractOnOtherSide, data, requestGasLimit);
  }

  function _setCoolDownPeriodLength(uint256 _coolDownPeriodLength) internal {
    require(_coolDownPeriodLength > 0, "StakingForeignMediator: unstake amount exceeds the balance");

    coolDownPeriodLength = _coolDownPeriodLength;
  }

  function _setYSTToken(address _token) internal {
    require(Address.isContract(_token), "Address should be a contract");
    stakingToken = IERC20(_token);

    emit SetYSTToken(_token);
  }

  // GETTERS

  function balanceOf(address _delegate) external view returns (uint256) {
    return _balances[_delegate];
  }

  function balanceCacheLength(address __delegate) external view returns (uint256) {
    return _cachedBalances[__delegate].length;
  }

  function totalSupplyCacheLength() external view returns (uint256) {
    return _cachedTotalSupply.length;
  }

  function balanceRecordAt(address __delegate, uint256 __cacheSlot)
    public
    view
    returns (uint256 timestamp, uint256 value)
  {
    Checkpoint storage checkpoint = _cachedBalances[__delegate][__cacheSlot];
    return (checkpoint.fromTimestamp, checkpoint.value);
  }

  function totalSupplyRecordSlot(uint256 __cacheSlot) public view returns (uint256 timestamp, uint256 value) {
    Checkpoint storage checkpoint = _cachedTotalSupply[__cacheSlot];
    return (checkpoint.fromTimestamp, checkpoint.value);
  }
}
