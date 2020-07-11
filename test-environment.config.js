module.exports = {
  accounts: {
    amount: 10, // Number of unlocked accounts
    ether: 5000000, // Initial balance of unlocked accounts (in ether)
  },

  contracts: {
    type: 'truffle', // Contract abstraction to use: 'truffle' for @truffle/contract or 'web3' for web3-eth-contract
    defaultGas: 9600000, // Maximum gas for contract calls (when unspecified)

    // Options available since v0.1.2
    defaultGasPrice: 1e9, // Gas price for contract calls (when unspecified)
    artifactsDir: 'build/contracts', // Directory where contract artifacts are stored
  },

  node: {
    // Options passed directly to Ganache client
    gasLimit: 96000000, // Maximum gas per block
    gasPrice: 1e9, // Sets the default gas price for transactions if not otherwise specified.
    port: 56990,
  },
  setupProvider: (baseProvider) => {
    return baseProvider;
  },
};
