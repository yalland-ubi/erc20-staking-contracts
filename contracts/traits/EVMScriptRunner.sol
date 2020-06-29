/*
 * Copyright ©️ 2020 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2020 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity 0.5.17;

contract EVMScriptRunner {
  /* This is manually crafted in assembly
  string private constant ERROR_EXECUTOR_INVALID_RETURN = "EVMRUN_EXECUTOR_INVALID_RETURN";
  */

  event ScriptResult(address indexed destination, bytes script, bytes returnData);

  /**
   * @dev Executes script, reverts if the execution fails
   * @param _script to execute. Notice, that the script format is not compatible with evmScript format from Aragon.
   *                Also, there is no support of several call scripts within a several tx.
   */
  function _runScript(bytes memory _script) internal {
    (address destination, bytes memory data) = abi.decode(_script, (address, bytes));

    // TODO: calculate the exact gas deduction value for further operations
    // solhint-disable-next-line avoid-low-level-calls
    (bool ok, bytes memory output) = destination.call(data);

    if (!ok) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        let ptr := mload(0x40)

        switch returndatasize
          case 0 {
            // No error data was returned, revert with "EVMCALLS_CALL_REVERTED"
            // See remix: doing a `revert("EVMCALLS_CALL_REVERTED")` always results in
            // this memory layout
            mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000) // error identifier
            mstore(add(ptr, 0x04), 0x0000000000000000000000000000000000000000000000000000000000000020) // starting offset
            mstore(add(ptr, 0x24), 0x0000000000000000000000000000000000000000000000000000000000000016) // reason length
            mstore(add(ptr, 0x44), 0x45564d43414c4c535f43414c4c5f524556455254454400000000000000000000) // reason

            revert(ptr, 100) // 100 = 4 + 3 * 32 (error identifier + 3 words for the ABI encoded error)
          }
          default {
            // Forward the full error data
            returndatacopy(ptr, 0, returndatasize)
            revert(ptr, returndatasize)
          }
      }
    }

    emit ScriptResult(destination, _script, output);
  }
}
