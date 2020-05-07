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
//  event FailedMessageFixed(bytes32 indexed dataHash, address recipient, uint256 tokenId);

  bytes4 internal constant GET_DETAILS = 0xb93a89f7; // getDetails(uint256)

  bytes32 internal nonce;
  mapping(bytes32 => uint256) internal messageHashTokenId;
  mapping(bytes32 => address) internal messageHashRecipient;
  mapping(bytes32 => bool) public messageHashFixed;

  function _initialize(
    address _bridgeContract,
    address _mediatorContractOnOtherSide,
    uint256 _requestGasLimit,
    uint256 _oppositeChainId,
    address _owner
  )
    internal
    returns (bool)
  {
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

  function getBridgeInterfacesVersion() external pure returns (uint64 major, uint64 minor, uint64 patch) {
    return (1, 0, 0);
  }

  function getBridgeMode() external pure returns (bytes4 _data) {
    return bytes4(keccak256(abi.encodePacked("yst-to-yst-amb")));
  }

  // USER INTERFACE

//  function getMetadata(uint256 _tokenId) public view returns (bytes memory metadata) {
//    bytes memory callData = abi.encodeWithSelector(GET_DETAILS, _tokenId);
//    address tokenAddress = address(erc721Token);
//    uint256 size;
//
//    assembly {
//      let result := staticcall(gas, tokenAddress, add(callData, 0x20), mload(callData), 0, 0)
//      size := returndatasize
//
//      switch result
//      case 0 { revert(0, 0) }
//    }
//
//    metadata = new bytes(size);
//
//    assembly {
//      returndatacopy(add(metadata, 0x20), 0, size)
//    }
//  }
//
  function setNonce(bytes32 _hash) internal {
    nonce = _hash;
  }

  function setMessageHashTokenId(bytes32 _hash, uint256 _tokenId) internal {
    messageHashTokenId[_hash] = _tokenId;
  }

  function setMessageHashRecipient(bytes32 _hash, address _recipient) internal {
    messageHashRecipient[_hash] = _recipient;
  }

//  function setMessageHashFixed(bytes32 _hash) internal {
//    messageHashFixed[_hash] = true;
//  }
//
//  function requestFailedMessageFix(bytes32 _txHash) external {
//    require(!bridgeContract.messageCallStatus(_txHash), "No fix required");
//    require(bridgeContract.failedMessageReceiver(_txHash) == address(this), "Invalid receiver");
//    require(bridgeContract.failedMessageSender(_txHash) == mediatorContractOnOtherSide, "Invalid sender");
//    bytes32 dataHash = bridgeContract.failedMessageDataHash(_txHash);
//
//    bytes4 methodSelector = this.fixFailedMessage.selector;
//    bytes memory data = abi.encodeWithSelector(methodSelector, dataHash);
//    bridgeContract.requireToPassMessage(mediatorContractOnOtherSide, data, requestGasLimit);
//
//    emit RequestFailedMessageFix(_txHash);
//  }
}
