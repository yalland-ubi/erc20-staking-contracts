/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;


interface IStakingHomeMediator {
  function setCachedBalance(
    address __delegator,
    uint256 __balance,
    uint256 __totalSupply,
    uint256 __timestamp
  ) external;
  
  // GETTERS
  function balanceOfAt(address __delegate, uint256 __timestamp) external view returns (uint256);
  function totalSupplyAt(uint256 __timestamp) external view returns (uint256);
}
