/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "./mediators/BasicStakingMediator.sol";
import "./interfaces/IStakingHomeMediator.sol";


contract StakingHomeMediator is IStakingHomeMediator, BasicStakingMediator {
  uint256 public tree = 0;
  uint256 public lastTime = 0;

  function initialize(
    address __bridgeContract,
    address __mediatorContractOnOtherSide,
    uint256 __requestGasLimit,
    uint256 __oppositeChainId,
    address __owner
  ) external {
    _initialize(__bridgeContract, __mediatorContractOnOtherSide, __requestGasLimit, __oppositeChainId, __owner);
  }

  event SetCachedBalance(address delegator, uint256 balance, uint256 totalSupply, uint256 timestamp);

  function setCachedBalance(
    address __delegator,
    uint256 __balance,
    uint256 __totalSupply,
    uint256 __timestamp
  ) external {
    require(msg.sender == address(bridgeContract), "Only bridge allowed");
    require(bridgeContract.messageSender() == mediatorContractOnOtherSide, "Invalid contract on other side");
    if (_cachedBalances[__delegator].length > 0) {
      require(
        __timestamp >= _cachedBalances[__delegator][_cachedBalances[__delegator].length - 1].fromTimestamp,
        "Timestamp should be greater than the last one"
      );
    }
    if (_cachedTotalSupply.length > 0) {
      require(
        __timestamp >= _cachedTotalSupply[_cachedTotalSupply.length - 1].fromTimestamp,
        "Timestamp should be greater than the last one"
      );
    }

    _updateValueAt(_cachedBalances[__delegator], __balance, __timestamp);
    _updateValueAt(_cachedTotalSupply, __totalSupply, __timestamp);

    emit SetCachedBalance(__delegator, __balance, __totalSupply, __timestamp);
  }
}
