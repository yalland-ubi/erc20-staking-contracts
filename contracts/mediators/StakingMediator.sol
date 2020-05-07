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


contract StakingMediator is Ownable, Initializable, AMBMediator, TimestampCheckpointable {
  event RequestFailedMessageFix(bytes32 indexed txHash);

  bytes32 internal _nonce;

  function _initialize(
    address _bridgeContract,
    address _mediatorContractOnOtherSide,
    uint256 _requestGasLimit,
    uint256 _oppositeChainId,
    address _owner
  ) internal returns (bool) {
    _setBridgeContract(_bridgeContract);
    _setMediatorContractOnOtherSide(_mediatorContractOnOtherSide);
    _setRequestGasLimit(_requestGasLimit);

    oppositeChainId = _oppositeChainId;

    setNonce(keccak256(abi.encodePacked(address(this))));

    _transferOwnership(_owner);

    return true;
  }

  // ABSTRACT METHODS

  //  function fixFailedMessage(bytes32 _dataHash) external;

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
    return bytes4(keccak256(abi.encodePacked("yst-to-yst-amb")));
  }

  // USER INTERFACE

  function _setNonce(bytes32 _hash) internal {
    _nonce = _hash;
  }
}
