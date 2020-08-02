const { accounts, defaultSender } = require('@openzeppelin/test-environment');
// eslint-disable-next-line import/order
const { contract } = require('./twrapper');
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
  const [alice, bob, charlie, mediatorOnTheOtherSide, stakeSlasher] = accounts;

  const coolDownPeriodLength = 3600;

  let proxyAdmin;
  let stakingToken;
  let foreignMediator;
  let homeMediator;
  let bridge;

  beforeEach(async function () {
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

    await stakingToken.transfer(alice, ether(30));
    await stakingToken.transfer(bob, ether(20));
    await stakingToken.transfer(charlie, ether(50));
  });

  it('should increment/decrement current balance on stake/unstake', async function () {
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

    // unlocked balance stake checks
    assert.equal(await foreignMediator.unlockedBalanceOf(alice), ether(30));
    assert.equal(await foreignMediator.unlockedBalanceOf(bob), ether(20));
    assert.equal(await foreignMediator.unlockedBalanceOf(charlie), ether(50));
    assert.equal(await foreignMediator.totalUnlocked(), ether(100));

    // unstake
    await foreignMediator.unstake(ether(10), { from: alice });
    await foreignMediator.unstake(ether(10), { from: bob });
    await foreignMediator.unstake(ether(10), { from: charlie });

    // balance stake checks
    assert.equal(await foreignMediator.balanceOf(alice), ether(20));
    assert.equal(await foreignMediator.balanceOf(bob), ether(10));
    assert.equal(await foreignMediator.balanceOf(charlie), ether(40));
    assert.equal(await foreignMediator.totalSupply(), ether(70));

    // unlocked balance stake checks
    assert.equal(await foreignMediator.unlockedBalanceOf(alice), ether(20));
    assert.equal(await foreignMediator.unlockedBalanceOf(bob), ether(10));
    assert.equal(await foreignMediator.unlockedBalanceOf(charlie), ether(40));
    assert.equal(await foreignMediator.totalUnlocked(), ether(70));
  });

  it('should update locked/unlocked balances on locking', async function () {
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

    // unlocked balance stake checks
    assert.equal(await foreignMediator.unlockedBalanceOf(alice), ether(30));
    assert.equal(await foreignMediator.unlockedBalanceOf(bob), ether(20));
    assert.equal(await foreignMediator.unlockedBalanceOf(charlie), ether(50));
    assert.equal(await foreignMediator.totalUnlocked(), ether(100));

    // Step #1. Lock...
    await assertRevert(
      foreignMediator.lock(ether(31), { from: alice }),
      ' StakingForeignMediator: Lock amount exceeds the balance'
    );
    await foreignMediator.lock(ether(30), { from: alice });
    await assertRevert(
      foreignMediator.lock(ether(1), { from: alice }),
      ' StakingForeignMediator: Lock amount exceeds the balance'
    );
    await foreignMediator.lock(ether(10), { from: bob });
    await foreignMediator.lock(ether(10), { from: charlie });

    // stake checks
    assert.equal(await foreignMediator.balanceOf(alice), ether(30));
    assert.equal(await foreignMediator.balanceOf(bob), ether(20));
    assert.equal(await foreignMediator.balanceOf(charlie), ether(50));
    assert.equal(await foreignMediator.totalSupply(), ether(100));

    // unlocked balance stake checks
    assert.equal(await foreignMediator.unlockedBalanceOf(alice), ether(0));
    assert.equal(await foreignMediator.unlockedBalanceOf(bob), ether(10));
    assert.equal(await foreignMediator.unlockedBalanceOf(charlie), ether(40));
    assert.equal(await foreignMediator.totalUnlocked(), ether(50));

    // locked balance stake checks
    assert.equal(await foreignMediator.lockedBalanceOf(alice), ether(30));
    assert.equal(await foreignMediator.lockedBalanceOf(bob), ether(10));
    assert.equal(await foreignMediator.lockedBalanceOf(charlie), ether(10));
    assert.equal(await foreignMediator.totalLocked(), ether(50));

    // Step #2. Slash
    await foreignMediator.setLockedStakeSlasher(stakeSlasher);
    await assertRevert(
      foreignMediator.setLockedStakeSlasher(stakeSlasher, { from: alice }),
      'Ownable: caller is not the owner'
    );

    await assertRevert(
      foreignMediator.slashLocked(alice, ether(31), { from: alice }),
      'StakingForeignMediator: Only lockedStakeSlasher allowed'
    );
    await assertRevert(
      foreignMediator.slashLocked(alice, ether(31), { from: stakeSlasher }),
      'StakingForeignMediator: Slash amount exceeds the locked balance'
    );
    let res = await foreignMediator.slashLocked(alice, ether(30), { from: stakeSlasher });
    const slash1At = await getResTimestamp(res);
    res = await foreignMediator.slashLocked(bob, ether(10), { from: stakeSlasher });
    const slash2At = await getResTimestamp(res);
    res = await foreignMediator.slashLocked(charlie, ether(5), { from: stakeSlasher });
    const slash3At = await getResTimestamp(res);

    // stake checks
    assert.equal(await foreignMediator.balanceOf(alice), ether(0));
    assert.equal(await foreignMediator.balanceOf(bob), ether(10));
    assert.equal(await foreignMediator.balanceOf(charlie), ether(45));
    assert.equal(await foreignMediator.totalSupply(), ether(55));

    // unlocked balance stake checks
    assert.equal(await foreignMediator.unlockedBalanceOf(alice), ether(0));
    assert.equal(await foreignMediator.unlockedBalanceOf(bob), ether(10));
    assert.equal(await foreignMediator.unlockedBalanceOf(charlie), ether(40));
    assert.equal(await foreignMediator.totalUnlocked(), ether(50));

    // locked balance stake checks
    assert.equal(await foreignMediator.lockedBalanceOf(alice), ether(0));
    assert.equal(await foreignMediator.lockedBalanceOf(bob), ether(0));
    assert.equal(await foreignMediator.lockedBalanceOf(charlie), ether(5));
    assert.equal(await foreignMediator.totalLocked(), ether(5));

    // check cooldown boxes
    let box = await foreignMediator.coolDownBoxes(1);
    assert.equal(box.holder, stakeSlasher);
    assert.equal(box.released, false);
    assert.equal(box.amount, ether(30));
    assert.equal(box.canBeReleasedSince, slash1At + coolDownPeriodLength);
    box = await foreignMediator.coolDownBoxes(2);
    assert.equal(box.holder, stakeSlasher);
    assert.equal(box.released, false);
    assert.equal(box.amount, ether(10));
    assert.equal(box.canBeReleasedSince, slash2At + coolDownPeriodLength);
    box = await foreignMediator.coolDownBoxes(3);
    assert.equal(box.holder, stakeSlasher);
    assert.equal(box.released, false);
    assert.equal(box.amount, ether(5));
    assert.equal(box.canBeReleasedSince, slash3At + coolDownPeriodLength);
  });

  it('should increment/decrement cached balance', async function () {
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
      'StakingForeignMediator: Unstake amount exceeds the unlocked balance'
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

  it('should create cooldown box on unstake', async function () {
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
      'StakingForeignMediator: Cannot be released yet'
    );

    await increaseTime(coolDownPeriodLength - 100);

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: alice }),
      'StakingForeignMediator: Cannot be released yet'
    );

    await increaseTime(150);

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: bob }),
      ' StakingForeignMediator: Only box holder allowed'
    );

    foreignMediator.releaseCoolDownBox(1, { from: alice });

    await assertRevert(
      foreignMediator.releaseCoolDownBox(1, { from: alice }),
      'StakingForeignMediator: The box has been already released'
    );
  });

  it('should notify AMB', async function () {
    await stakingToken.approve(foreignMediator.address, ether(30), {
      from: alice,
    });
    const res = await foreignMediator.stake(ether(30), { from: alice });
    const at = await getResTimestamp(res);

    const receipt = await web3.eth.getTransactionReceipt(res.tx);
    const logs = AMBMock.decodeLogs(receipt.logs);

    assert.equal(
      logs[1].args.data,
      homeMediator.contract.methods.setCachedBalance(alice, ether(30), ether(30), at).encodeABI()
    );
  });
});
