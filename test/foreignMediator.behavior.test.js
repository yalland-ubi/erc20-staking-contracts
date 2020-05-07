const { accounts, contract, web3, defaultSender } = require('@openzeppelin/test-environment');
const { assert } = require('chai');

const AMBMock = contract.fromArtifact('AMBMock');
const ProxyAdmin = contract.fromArtifact('ProxyAdmin');
const Proxy = contract.fromArtifact('AdminUpgradeabilityProxy');
const YGovernanceToken = contract.fromArtifact('YGovernanceToken');
const YGovernanceForeignMediator = contract.fromArtifact('YGovernanceForeignMediator');
const YGovernanceHomeMediator = contract.fromArtifact('YGovernanceHomeMediator');

AMBMock.numberFormat = 'String';
YGovernanceToken.numberFormat = 'String';
YGovernanceForeignMediator.numberFormat = 'String';

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

describe('YStaking Integration tests', () => {
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
    stakingToken = await YGovernanceToken.new('My Staking Token', 'MST', 18, ether(250));
    // only for ABI sake
    homeMediator = await YGovernanceHomeMediator.new();
    proxyAdmin = await ProxyAdmin.new();
    const res = await deployWithProxy(
      YGovernanceForeignMediator,
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

    await stakingToken.transfer(alice, ether(30));
    await stakingToken.transfer(bob, ether(20));
    await stakingToken.transfer(charlie, ether(50));
  });

  it('should increment/decrement current balance on stake/unstake', async function() {
    assert.equal(await foreignMediator.totalSupply(), 0);

    // approve
    await stakingToken.approve(foreignMediator.address, ether(30), {
      from: alice,
    });
    await stakingToken.approve(foreignMediator.address, ether(20), { from: bob });
    await stakingToken.approve(foreignMediator.address, ether(50), {
      from: charlie,
    });

    // stake
    await foreignMediator.stake(ether(10), { from: alice });
    await foreignMediator.stake(ether(20), { from: alice });
    await foreignMediator.stake(ether(20), { from: bob });
    await foreignMediator.stake(ether(50), { from: charlie });

    // stake checks
    assert.equal(await foreignMediator.balanceOf(alice), ether(30));
    assert.equal(await foreignMediator.balanceOf(bob), ether(20));
    assert.equal(await foreignMediator.balanceOf(charlie), ether(50));
    assert.equal(await foreignMediator.totalSupply(), ether(100));

    // unstake
    await foreignMediator.unstake(ether(10), { from: alice });
    await foreignMediator.unstake(ether(10), { from: bob });
    await foreignMediator.unstake(ether(10), { from: charlie });

    // stake checks
    assert.equal(await foreignMediator.balanceOf(alice), ether(20));
    assert.equal(await foreignMediator.balanceOf(bob), ether(10));
    assert.equal(await foreignMediator.balanceOf(charlie), ether(40));
    assert.equal(await foreignMediator.totalSupply(), ether(70));
  });

  it('should increment/decrement cached balance', async function() {
    // step1 (alice=0, bob=0, charlie=0, total=0)
    const step0 = await now();
    assert.equal(await foreignMediator.balanceOfAt(alice, step0), 0);
    assert.equal(await foreignMediator.totalSupplyAt(step0), 0);

    // step1 changes to (alice=30, bob=0, charlie=0, total=30)
    await increaseTime(10);

    await stakingToken.approve(foreignMediator.address, ether(30), {
      from: alice,
    });
    let res = await foreignMediator.stake(ether(30), { from: alice });
    const step1 = await getResTimestamp(res);

    assert.equal(await foreignMediator.balanceOfAt(alice, step1), ether(30));
    assert.equal(await foreignMediator.totalSupplyAt(step1), ether(30));
    assert.equal(await foreignMediator.balanceOfAt(alice, step1 - 1), 0);
    assert.equal(await foreignMediator.totalSupplyAt(step1 - 1), 0);

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
      'YALLStakingMediator: unstake amount exceeds the balance'
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

  it('should create cooldown box on unstake', async function() {
    await stakingToken.approve(foreignMediator.address, ether(30), {
      from: alice,
    });
    await foreignMediator.stake(ether(30), { from: alice });

    const aliceBalanceBefore = await stakingToken.balanceOf(alice);
    const res = await foreignMediator.unstake(ether(20), { from: alice });
    const aliceBalanceAfter = await stakingToken.balanceOf(alice);

    assertErc20BalanceChanged(aliceBalanceBefore, aliceBalanceAfter, '0');

    const canBeReleasedSince = (await getResTimestamp(res)) + coolDownPeriodLength;
    assert.equal(getEventArg(res, 'NewCoolDownBox', 'delegator'), alice);
    assert.equal(getEventArg(res, 'NewCoolDownBox', 'boxId'), 1);
    assert.equal(getEventArg(res, 'NewCoolDownBox', 'amount'), ether(20));
    assert.equal(getEventArg(res, 'NewCoolDownBox', 'canBeReleasedSince'), canBeReleasedSince);

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: alice }),
      'YALLStakingMediator: cannot be released yet'
    );

    await increaseTime(coolDownPeriodLength - 100);

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: alice }),
      'YALLStakingMediator: cannot be released yet'
    );

    await increaseTime(150);

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: bob }),
      ' YALLStakingMediator: only box holder allowed'
    );

    foreignMediator.releaseCoolDownBox(1, { from: alice });

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: alice }),
      'YALLStakingMediator: the box has been already released'
    );
  });

  it('should notify AMB', async function() {
    await stakingToken.approve(foreignMediator.address, ether(30), {
      from: alice,
    });
    const res = await foreignMediator.stake(ether(30), { from: alice });
    const at = await getResTimestamp(res);

    const receipt = await web3.eth.getTransactionReceipt(res.tx);
    const logs = AMBMock.decodeLogs(receipt.logs);

    assert.equal(logs[1].args.data, homeMediator.contract.methods.setCachedBalance(alice, at, ether(30)).encodeABI());
  });
});
