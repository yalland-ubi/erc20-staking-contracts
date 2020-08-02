/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./interfaces/IAMB.sol";

contract AMBMediator is Ownable {
  event SetBridgeContract(address bridgeContract);
  event SetMediatorContractOnOtherSide(address mediatorContract);
  event SetRequestGasLimit(uint256 requestGasLimit);

  uint256 public oppositeChainId;
  IAMB public bridgeContract;
  address public mediatorContractOnOtherSide;
  uint256 public requestGasLimit;

  // OWNER INTERFACE

  function setBridgeContract(address __bridgeContract) external onlyOwner {
    _setBridgeContract(__bridgeContract);
  }

  function setMediatorContractOnOtherSide(address __mediatorContract) external onlyOwner {
    _setMediatorContractOnOtherSide(__mediatorContract);
  }

  function setRequestGasLimit(uint256 __requestGasLimit) external onlyOwner {
    _setRequestGasLimit(__requestGasLimit);
  }

  // INTERNAL

  function _setBridgeContract(address __bridgeContract) internal {
    require(Address.isContract(__bridgeContract), "AMBMediator: Address should be a contract");
    bridgeContract = IAMB(__bridgeContract);

    emit SetBridgeContract(__bridgeContract);
  }

  function _setMediatorContractOnOtherSide(address __mediatorContract) internal {
    mediatorContractOnOtherSide = __mediatorContract;

    emit SetMediatorContractOnOtherSide(__mediatorContract);
  }

  function _setRequestGasLimit(uint256 __requestGasLimit) internal {
    require(__requestGasLimit <= bridgeContract.maxGasPerTx(), "AMBMediator: Gas value exceeds bridge limit");
    requestGasLimit = __requestGasLimit;

    emit SetRequestGasLimit(__requestGasLimit);
  }
}
