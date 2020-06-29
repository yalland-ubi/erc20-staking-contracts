/*
 * Copyright ©️ 2018-2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2018-2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "./AMBMediator.sol";

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../traits/TimestampCheckpointable.sol";

contract BasicStakingMediator is Ownable, Initializable, AMBMediator, TimestampCheckpointable {
  event RequestFailedMessageFix(bytes32 indexed txHash);

  bytes32 internal _nonce;

  function _initialize(
    address __bridgeContract,
    address __mediatorContractOnOtherSide,
    uint256 __requestGasLimit,
    uint256 __oppositeChainId,
    address __owner
  ) internal initializer {
    _setBridgeContract(__bridgeContract);
    _setMediatorContractOnOtherSide(__mediatorContractOnOtherSide);
    _setRequestGasLimit(__requestGasLimit);

    oppositeChainId = __oppositeChainId;

    _setNonce(keccak256(abi.encodePacked(address(this))));

    _transferOwnership(__owner);
  }

  // INFO GETTERS

  function getBridgeInterfacesVersion()
    external
    pure
    returns (
      uint64 major,
      uint64 minor,
      uint64 patch
    )
  {
    return (1, 0, 0);
  }

  function getBridgeMode() external pure returns (bytes4 _data) {
    return bytes4(keccak256(abi.encodePacked("stake-to-stake-amb")));
  }

  // USER INTERFACE

  function _setNonce(bytes32 __hash) internal {
    _nonce = __hash;
  }

  // GETTERS

  function balanceOfAt(address __delegator, uint256 __timestamp) public view returns (uint256) {
    return _getValueAt(_cachedBalances[__delegator], __timestamp);
  }

  function totalSupplyAt(uint256 __timestamp) public view returns (uint256) {
    return _getValueAt(_cachedTotalSupply, __timestamp);
  }
}
