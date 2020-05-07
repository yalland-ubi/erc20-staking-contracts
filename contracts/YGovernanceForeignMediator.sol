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
import "./mediators/StakingMediator.sol";
import "./traits/NumericIdCounter.sol";
import "./interfaces/IYGovernanceHomeMediator.sol";


contract YGovernanceForeignMediator is StakingMediator, NumericIdCounter {
  using SafeMath for uint256;
  using SafeCast for uint256;

  event Stake(address indexed delegate, uint256 at, uint256 amount, uint256 balanceBefore, uint256 balanceAfter);
  event Unstake(address indexed delegate, uint256 at, uint256 amount, uint256 balanceBefore, uint256 balanceAfter);
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
    _postCachedBalance(msg.sender, now, _amount);
  }

  function unstake(uint256 _amount) external {
    require(_balances[msg.sender] >= _amount, "YALLStakingMediator: unstake amount exceeds the balance");

    _applyUnstake(msg.sender, _amount);

    uint256 boxId = _nextCounterId();
    uint64 canBeReleasedSince = (now + coolDownPeriodLength).toUint64();
    require(canBeReleasedSince > now, "YALLStakingMediator: either overflow or 0 cooldown period");

    coolDownBoxes[boxId] = CoolDownBox({
      holder: msg.sender,
      amount: _amount,
      released: false,
      canBeReleasedSince: canBeReleasedSince,
      releasedAt: 0
    });

    emit NewCoolDownBox(msg.sender, boxId, _amount, canBeReleasedSince);

    _postCachedBalance(msg.sender, now, _amount);
  }

  function releaseCoolDownBox(uint256 _boxId) external {
    CoolDownBox storage box = coolDownBoxes[_boxId];

    require(now > box.canBeReleasedSince, "YALLStakingMediator: cannot be released yet");
    require(box.holder == msg.sender, "YALLStakingMediator: only box holder allowed");
    require(box.released == false, "YALLStakingMediator: the box has been already released");

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

    emit Stake(_delegate, now, _amount, balanceBefore, balanceAfter);
  }

  function _applyUnstake(address _delegate, uint256 _amount) internal {
    uint256 balanceBefore = _balances[_delegate];
    uint256 balanceAfter = balanceBefore.sub(_amount);
    uint256 totalSupplyAfter = totalSupply.sub(_amount);

    _balances[_delegate] = balanceAfter;
    totalSupply = totalSupplyAfter;

    _updateValueAtNow(_cachedBalances[_delegate], balanceAfter);
    _updateValueAtNow(_cachedTotalSupply, totalSupplyAfter);

    emit Unstake(_delegate, now, _amount, balanceBefore, balanceAfter);
  }

  function _postCachedBalance(
    address _delegate,
    uint256 _at,
    uint256 _amount
  ) internal {
    bytes4 methodSelector = IYGovernanceHomeMediator(0).setCachedBalance.selector;
    bytes memory data = abi.encodeWithSelector(methodSelector, _delegate, _at, _amount);

    bytes32 dataHash = keccak256(data);
    _setNonce(dataHash);

    bridgeContract.requireToPassMessage(mediatorContractOnOtherSide, data, requestGasLimit);
  }

  function _setCoolDownPeriodLength(uint256 _coolDownPeriodLength) internal {
    require(_coolDownPeriodLength > 0, "YALLStakingMediator: unstake amount exceeds the balance");

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

  function balanceOfAt(address _delegate, uint256 _timestamp) external view returns (uint256) {
    return _getValueAt(_cachedBalances[_delegate], _timestamp);
  }

  function totalSupplyAt(uint256 _timestamp) external view returns (uint256) {
    return _getValueAt(_cachedTotalSupply, _timestamp);
  }
}
