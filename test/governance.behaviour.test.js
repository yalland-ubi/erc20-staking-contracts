const { accounts, contract, web3, defaultSender } = require('@openzeppelin/test-environment');
const { assert } = require('chai');

const AMBMock = contract.fromArtifact('AMBMock');
const ProxyAdmin = contract.fromArtifact('ProxyAdmin');
const Proxy = contract.fromArtifact('AdminUpgradeabilityProxy');
const StakingToken = contract.fromArtifact('StakingToken');
const StakingForeignMediator = contract.fromArtifact('StakingForeignMediator');
const StakingHomeMediator = contract.fromArtifact('StakingHomeMediator');
const StakingGovernance = contract.fromArtifact('StakingGovernance');

AMBMock.numberFormat = 'String';
StakingGovernance.numberFormat = 'String';
StakingToken.numberFormat = 'String';
StakingForeignMediator.numberFormat = 'String';
StakingHomeMediator.numberFormat = 'String';

const {
  ether,
  now,
  increaseTime,
  assertRevert,
  zeroAddress,
  getEventArg,
  getResTimestamp,
} = require('@galtproject/solidity-test-chest')(web3);

const keccak256 = web3.utils.soliditySha3;

async function deployWithProxy(implContract, proxyAdminContract, ...args) {
  const implementation = await implContract.new();
  const proxy = await Proxy.new(
    implementation.address,
    proxyAdminContract.address,
    implementation.contract.methods.initialize(...args).encodeABI()
  );

  // eslint-disable-next-line no-shadow
  const contract = await implContract.at(proxy.address);

  return {
    implementation,
    proxy,
    contract,
  };
}

async function getProxyAdmin(addr) {
  return web3.utils.toChecksumAddress(
    await web3.eth.getStorageAt(addr, '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103')
  );
}

describe('StakingHomeMediator Behaviour tests', () => {
  const [alice, bob, charlie] = accounts;

  const coolDownPeriodLength = 3600;
  const supportRequiredPct = ether('0.6');
  const minAcceptQuorumPct = ether('0.4');
  const voteTime = '3600';

  let proxyAdmin;
  let governance;
  let stakingToken;
  let foreignMediatorProxy;
  let foreignMediator;
  let homeMediator;
  let bridge;

  beforeEach(async function() {
    bridge = await AMBMock.new();
    await bridge.setMaxGasPerTx(2000000);
    stakingToken = await StakingToken.new('My Staking Token', 'MST', 18, ether(250));

    // only for ABI sake
    proxyAdmin = await ProxyAdmin.new();

    let res = await deployWithProxy(
      StakingForeignMediator,
      proxyAdmin,
      // initialize() arguments
      bridge.address,
      alice,
      stakingToken.address,
      // requestGasLimit
      2000000,
      // oppositeChainId,
      42,
      coolDownPeriodLength,
      // owner
      defaultSender
    );
    foreignMediator = res.contract;
    foreignMediatorProxy = res.proxy;

    res = await deployWithProxy(
      StakingGovernance,
      proxyAdmin,
      foreignMediator.address,
      supportRequiredPct,
      minAcceptQuorumPct,
      voteTime
    );
    governance = res.contract;

    await bridge.setForeignMediator(foreignMediator.address);

    await stakingToken.transfer(alice, ether(30));
    await stakingToken.transfer(bob, ether(20));
    await stakingToken.transfer(charlie, ether(50));

    await proxyAdmin.transferOwnership(governance.address);

    await increaseTime(10);

    await stakingToken.approve(foreignMediator.address, ether(30), { from: alice });
    await foreignMediator.stake(ether(30), { from: alice });

    await increaseTime(10);

    assert.equal(await foreignMediator.balanceOfAt(alice, await now()), ether(30));
    assert.equal(await foreignMediator.totalSupplyAt(await now()), ether(30));
  });

  it('allow creating and approving proposal for an external contract', async function() {
    assert.equal(await proxyAdmin.owner(), governance.address);
    assert.equal(await proxyAdmin.getProxyAdmin(foreignMediator.address), proxyAdmin.address);

    const payload = proxyAdmin.contract.methods.changeProxyAdmin(foreignMediator.address, bob).encodeABI();
    const data = web3.eth.abi.encodeParameters(['address', 'bytes'], [proxyAdmin.address, payload]);
    await assertRevert(governance.newVote(payload, 'foo', false, false, { from: bob }), 'VOTING_CAN_CREATE_VOTE');
    await governance.newVote(data, 'foo', true, true, { from: alice });

    assert.equal(await getProxyAdmin(foreignMediator.address), bob);
  });

  it('allow creating and approving proposal for internal params', async function() {
    assert.equal(await governance.voteTime(), voteTime);
    assert.equal(await proxyAdmin.getProxyAdmin(foreignMediator.address), proxyAdmin.address);

    const payload = governance.contract.methods.changeVoteTime(42).encodeABI();
    const data = web3.eth.abi.encodeParameters(['address', 'bytes'], [governance.address, payload]);
    await governance.newVote(data, 'foo', true, true, { from: alice });

    assert.equal(await governance.voteTime(), 42);
  });
});
