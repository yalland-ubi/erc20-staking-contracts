/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity 0.5.17;


interface IStakingForeignMediator {
  // OWNER INTERFACE

  function setCoolDownPeriodLength(uint256 __coolDownPeriodLength) external;

  // DELEGATE INTERFACE

  function stake(uint256 _amount) external;

  function unstake(uint256 _amount) external;

  function pushCachedBalance(
    address __delegate,
    uint256 __delegateCacheSlotIndex,
    uint256 __totalSupplyCacheSlotIndex,
    uint256 __at
  ) external;

  function releaseCoolDownBox(uint256 __boxId) external;

  // GETTERS
  function balanceOf(address __delegate) external view returns (uint256);

  function balanceOfAt(address __delegate, uint256 __timestamp) external view returns (uint256);

  function totalSupplyAt(uint256 __timestamp) external view returns (uint256);

  function balanceCacheLength(address __delegate) external view returns (uint256);

  function totalSupplyCacheLength() external view returns (uint256);

  function balanceRecordAt(address __delegate, uint256 __cacheSlot)
    external
    view
    returns (uint256 timestamp, uint256 value);

  function totalSupplyRecordSlot(uint256 __cacheSlot) external view returns (uint256 timestamp, uint256 value);
}
