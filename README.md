# ERC20 Staking Contracts

![CI](https://github.com/yalland-ubi/erc20-staking-contracts/workflows/CI/badge.svg)
<a href="https://codecov.io/gh/yalland-ubi/erc20-staking-contracts" target="_blank">
  <img src="https://codecov.io/gh/yalland-ubi/erc20-staking-contracts/branch/master/graph/badge.svg" />
</a>

## Tech Stack

* [`POA Arbitrary Message Bridge`](https://docs.tokenbridge.net/amb-bridge/about-amb-bridge) used to transfer stake information across two different chains.
* [`MiniMeToken`](https://github.com/Giveth/minime)-like approach caches deposited stake information and prevents `double-spending` in terms of staked token.
* A slightly modified [`Aragon Voting`](https://github.com/aragon/aragon-apps/blob/master/apps/voting/contracts/Voting.sol) contract serves as a primary governance/decision-making point.

## Commands

* `make cleanup` - remove solidity build artifacts
* `make compile` - compile solidity files, executes `make cleanup` before compilation
* `make test` - run tests
* `make coverage` - run solidity coverage
* `make lint` - run solidity and javascript linters
* `make deploy` - run deployment scripts
* `make ganache` - run local pre-configured ganache

For more information check out `Makefile`
