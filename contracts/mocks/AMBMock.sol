pragma solidity ^0.5.13;

contract AMBMock {
  event MockedEvent(bytes encodedData);
  event MockedEventDetailed(address sender, address contractAddress, uint256 gas, bytes data);

  address public foreignMediator;
  address public homeMediator;
  address public messageId;
  address public messageSender;
  uint256 public maxGasPerTx;
  bytes32 public transactionHash;
  mapping(bytes32 => bool) public messageCallStatus;
  mapping(bytes32 => address) public failedMessageSender;
  mapping(bytes32 => address) public failedMessageReceiver;
  mapping(bytes32 => bytes32) public failedMessageDataHash;
  mapping(bytes32 => bytes) public failedReason;

  function setMaxGasPerTx(uint256 __value) external {
    maxGasPerTx = __value;
  }

  function setForeignMediator(address __foreignMediator) external {
    foreignMediator = __foreignMediator;
  }

  function setHomeMediator(address __homeMediator) external {
    homeMediator = __homeMediator;
  }

  function executeMessageCall(
    address __contract,
    address __sender,
    bytes memory __data,
    bytes32 __txHash,
    uint256 __gas
  ) public {
    messageSender = __sender;
    transactionHash = __txHash;
    // solhint-disable-next-line avoid-low-level-calls
    (bool status, bytes memory response) = __contract.call.gas(__gas)(__data);
    messageSender = address(0);
    transactionHash = bytes32(0);

    messageCallStatus[__txHash] = status;
    delete failedReason[__txHash];
    if (!status) {
      failedMessageDataHash[__txHash] = keccak256(__data);
      failedMessageReceiver[__txHash] = __contract;
      failedMessageSender[__txHash] = __sender;
      failedReason[__txHash] = response;
    }
  }

  function requireToPassMessage(
    address __contract,
    bytes memory __data,
    uint256 __gas
  ) public returns (bytes32) {
    emit MockedEvent(abi.encodePacked(msg.sender, __contract, __gas, uint8(0x00), __data));
    emit MockedEventDetailed(msg.sender, __contract, __gas, __data);

    if (msg.sender == homeMediator) {
      executeMessageCall(__contract, msg.sender, __data, keccak256("stub"), __gas);
    } else if (msg.sender == foreignMediator) {
      executeMessageCall(__contract, msg.sender, __data, keccak256("stub"), __gas);
    }

    return keccak256(abi.encode(now, msg.sender, __contract, __data));
  }
}
