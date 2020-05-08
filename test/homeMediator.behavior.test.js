const { accounts, contract, web3, defaultSender } = require('@openzeppelin/test-environment');
const { assert } = require('chai');

const AMBMock = contract.fromArtifact('AMBMock');
const ProxyAdmin = contract.fromArtifact('ProxyAdmin');
const Proxy = contract.fromArtifact('AdminUpgradeabilityProxy');
const StakingToken = contract.fromArtifact('StakingToken');
const StakingForeignMediator = contract.fromArtifact('StakingForeignMediator');
const StakingHomeMediator = contract.fromArtifact('StakingHomeMediator');

AMBMock.numberFormat = 'String';
StakingToken.numberFormat = 'String';
StakingForeignMediator.numberFormat = 'String';
StakingHomeMediator.numberFormat = 'String';

const {
  ether,
  now,
  increaseTime,
  assertRevert,
  getEventArg,
  getResTimestamp,
  assertErc20BalanceChanged,
} = require('@galtproject/solidity-test-chest')(web3);

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

describe('StakingForeignMediator Behaviour tests', () => {
  const [alice, bob, charlie, mediatorOnTheOtherSide] = accounts;

  const coolDownPeriodLength = 3600;

  let proxyAdmin;
  let stakingToken;
  let foreignMediator;
  let homeMediator;
  let bridge;

  beforeEach(async function() {
    bridge = await AMBMock.new();
    await bridge.setMaxGasPerTx(2000000);
    stakingToken = await StakingToken.new('My Staking Token', 'MST', 18, ether(250));
    // only for ABI sake
    homeMediator = await StakingHomeMediator.new();
    proxyAdmin = await ProxyAdmin.new();
    const res = await deployWithProxy(
      StakingForeignMediator,
      proxyAdmin,
      // initialize() arguments
      bridge.address,
      mediatorOnTheOtherSide,
      stakingToken.address,
      // requestGasLimit
      2000000,
      // oppositeChainId,
      0,
      coolDownPeriodLength,
      // owner
      defaultSender
    );
    foreignMediator = res.contract;

    await bridge.setForeignMediator(foreignMediator.address);
    await bridge.setHomeMediator(homeMediator.address);

    await stakingToken.transfer(alice, ether(30));
    await stakingToken.transfer(bob, ether(20));
    await stakingToken.transfer(charlie, ether(50));
  });

  it('should increment/decrement cached balance', async function() {
    // step1 (alice=0, bob=0, charlie=0, total=0)
    const step0 = await now();
    assert.equal(await homeMediator.balanceOfAt(alice, step0), 0);
    assert.equal(await homeMediator.totalSupplyAt(step0), 0);

    // step1 changes to (alice=30, bob=0, charlie=0, total=30)
    await increaseTime(10);

    await stakingToken.approve(foreignMediator.address, ether(30), {
      from: alice,
    });
    let res = await foreignMediator.stake(ether(30), { from: alice });
    const step1 = await getResTimestamp(res);

    assert.equal(await homeMediator.balanceOfAt(alice, step1), ether(30));
    assert.equal(await homeMediator.totalSupplyAt(step1), ether(30));
    assert.equal(await homeMediator.balanceOfAt(alice, step1 - 1), 0);
    assert.equal(await homeMediator.totalSupplyAt(step1 - 1), 0);

    // step2 changes to (alice=30, bob=20, charlie=0, total=50)
    await increaseTime(10);

    await stakingToken.approve(foreignMediator.address, ether(20), { from: bob });
    await assertRevert(foreignMediator.stake(ether(20), { from: alice }), 'ERC20: transfer amount exceeds balance');
    res = await foreignMediator.stake(ether(20), { from: bob });
    const step2 = await getResTimestamp(res);

    assert.equal(await foreignMediator.balanceOfAt(alice, step2), ether(30));
    assert.equal(await foreignMediator.balanceOfAt(bob, step2), ether(20));
    assert.equal(await foreignMediator.totalSupplyAt(step2), ether(50));
    assert.equal(await foreignMediator.balanceOfAt(alice, step2 - 1), ether(30));
    assert.equal(await foreignMediator.balanceOfAt(bob, step2 - 1), 0);
    assert.equal(await foreignMediator.totalSupplyAt(step2 - 1), ether(30));

    // step3 changes to (alice=30, bob=10, charlie=0, total=50)
    await increaseTime(10);

    await assertRevert(
      foreignMediator.unstake(ether(21), { from: bob }),
      'StakingForeignMediator: unstake amount exceeds the balance'
    );
    res = await foreignMediator.unstake(ether(10), { from: bob });
    const step3 = await getResTimestamp(res);

    assert.equal(await foreignMediator.balanceOfAt(alice, step3), ether(30));
    assert.equal(await foreignMediator.balanceOfAt(bob, step3), ether(10));
    assert.equal(await foreignMediator.totalSupplyAt(step3), ether(40));
    assert.equal(await foreignMediator.balanceOfAt(alice, step3 - 1), ether(30));
    assert.equal(await foreignMediator.balanceOfAt(bob, step3 - 1), ether(20));
    assert.equal(await foreignMediator.totalSupplyAt(step3 - 1), ether(50));
  });
});
