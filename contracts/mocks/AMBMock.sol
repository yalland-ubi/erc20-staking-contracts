pragma solidity ^0.5.13;


contract AMBMock {
  event MockedEvent(bytes encodedData);
  event MockedEventDetailed(address sender, address contractAddress, uint256 gas, bytes data);

  address public foreignMediator;
  address public homeMediator;
  address public messageSender;
  uint256 public maxGasPerTx;
  bytes32 public transactionHash;
  mapping(bytes32 => bool) public messageCallStatus;
  mapping(bytes32 => address) public failedMessageSender;
  mapping(bytes32 => address) public failedMessageReceiver;
  mapping(bytes32 => bytes32) public failedMessageDataHash;
  mapping(bytes32 => bytes) public failedReason;

  function setMaxGasPerTx(uint256 _value) external {
    maxGasPerTx = _value;
  }

  function setForeignMediator(address _foreignMediator) external {
    foreignMediator = _foreignMediator;
  }

  function setHomeMediator(address _homeMediator) external {
    homeMediator = _homeMediator;
  }

  function executeMessageCall(
    address _contract,
    address _sender,
    bytes memory _data,
    bytes32 _txHash,
    uint256 _gas
  ) public {
    messageSender = _sender;
    transactionHash = _txHash;
    // solhint-disable-next-line avoid-low-level-calls
    (bool status, bytes memory response) = _contract.call.gas(_gas)(_data);
    messageSender = address(0);
    transactionHash = bytes32(0);

    messageCallStatus[_txHash] = status;
    delete failedReason[_txHash];
    if (!status) {
      failedMessageDataHash[_txHash] = keccak256(_data);
      failedMessageReceiver[_txHash] = _contract;
      failedMessageSender[_txHash] = _sender;
      failedReason[_txHash] = response;
    }
  }

  function requireToPassMessage(
    address _contract,
    bytes memory _data,
    uint256 _gas
  ) public returns (bytes32) {
    emit MockedEvent(abi.encodePacked(msg.sender, _contract, _gas, uint8(0x00), _data));
    emit MockedEventDetailed(msg.sender, _contract, _gas, _data);

    if (msg.sender == homeMediator) {
      executeMessageCall(_contract, msg.sender, _data, keccak256("stub"), _gas);
    } else if (msg.sender == foreignMediator) {
      executeMessageCall(_contract, msg.sender, _data, keccak256("stub"), _gas);
    }

    return keccak256(abi.encode(now, msg.sender, _contract, _data));
  }
}
