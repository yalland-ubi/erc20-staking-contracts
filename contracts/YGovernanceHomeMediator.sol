/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "./mediators/StakingMediator.sol";
import "./interfaces/IYGovernanceHomeMediator.sol";


contract YGovernanceHomeMediator is IYGovernanceHomeMediator, StakingMediator {
  function setCachedBalance(
    address _delegator,
    uint256 _timestamp,
    uint256 _balance
  ) external {
    // TODO: implement logic
  }
}
