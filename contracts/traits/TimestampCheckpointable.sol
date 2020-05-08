/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;


contract TimestampCheckpointable {
  struct Checkpoint {
    uint128 fromTimestamp;
    uint128 value;
  }

  Checkpoint[] internal _cachedTotalSupply;
  mapping(address => Checkpoint[]) internal _cachedBalances;

  function _updateValueAtNow(Checkpoint[] storage __checkpoints, uint256 __value) internal {
    _updateValueAt(__checkpoints, __value, now);
  }

  function _updateValueAt(Checkpoint[] storage __checkpoints, uint256 __value, uint256 __value) internal {
    if ((__checkpoints.length == 0) || (__checkpoints[__checkpoints.length - 1].fromTimestamp < __value)) {
      Checkpoint storage newCheckPoint = __checkpoints[__checkpoints.length++];
      newCheckPoint.fromTimestamp = uint128(__value);
      newCheckPoint.value = uint128(__value);
    } else {
      Checkpoint storage oldCheckPoint = __checkpoints[__checkpoints.length - 1];
      oldCheckPoint.value = uint128(__value);
    }
  }

  function _getValueAt(Checkpoint[] storage checkpoints, uint256 _timestamp) internal view returns (uint256) {
    if (checkpoints.length == 0) {
      return 0;
    }

    // Shortcut for the actual value
    if (_timestamp >= checkpoints[checkpoints.length - 1].fromTimestamp) {
      return checkpoints[checkpoints.length - 1].value;
    }

    if (_timestamp < checkpoints[0].fromTimestamp) {
      return 0;
    }

    // Binary search of the value in the array
    uint256 min = 0;
    uint256 max = checkpoints.length - 1;
    while (max > min) {
      uint256 mid = (max + min + 1) / 2;
      if (checkpoints[mid].fromTimestamp <= _timestamp) {
        min = mid;
      } else {
        max = mid - 1;
      }
    }
    return checkpoints[min].value;
  }

  // GETTERS

  function _balanceOfAt(address _address, uint256 _timestamp) internal view returns (uint256) {
    if ((_cachedBalances[_address].length == 0) || (_cachedBalances[_address][0].fromTimestamp > _timestamp)) {
      return 0;
    } else {
      return _getValueAt(_cachedBalances[_address], _timestamp);
    }
  }

  function _totalSupplyAt(uint256 _timestamp) internal view returns (uint256) {
    if ((_cachedTotalSupply.length == 0) || (_cachedTotalSupply[0].fromTimestamp > _timestamp)) {
      return 0;
    } else {
      return _getValueAt(_cachedTotalSupply, _timestamp);
    }
  }
}
