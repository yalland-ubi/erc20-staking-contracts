/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract StakingToken is ERC20, ERC20Detailed {
  constructor(
    string memory _tokenName,
    string memory _tokenSymbol,
    uint8 _tokenDecimals,
    uint256 _initialSupply
  ) public ERC20Detailed(_tokenName, _tokenSymbol, _tokenDecimals) {
    _mint(msg.sender, _initialSupply);
  }
}
