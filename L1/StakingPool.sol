// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/Metis/ILockingPool.sol";
import "./Interfaces/IStakingPool.sol";
import "../Utils/AMTConstants.sol";

contract StakingPool is IStakingPool, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    ILockingPool public lockingPool;
    address public l1Token;
    address public stakingPoolManager;
    address public rewardRecipient;

    address public signer;
    uint256 public sequencerId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _lockingPool,
        address _l1Token,
        address _rewardRecipient,
        address _stakingPoolManager
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);

        require(_lockingPool != address(0), "StakingPool: invalid locking pool");
        require(_l1Token != address(0), "StakingPool: invalid l1 token");
        require(_stakingPoolManager != address(0), "StakingPool: invalid staking pool manager");
        require(_rewardRecipient != address(0), "StakingPool: invalid reward recipient");

        lockingPool = ILockingPool(_lockingPool);
        l1Token = _l1Token;
        stakingPoolManager = _stakingPoolManager;
        rewardRecipient = _rewardRecipient;

        emit PoolInitialized(_lockingPool, _l1Token, _stakingPoolManager, _rewardRecipient);
    }

    modifier onlyStakingManager() {
        require(msg.sender == stakingPoolManager, "StakingPool: only staking pool manager");
        _;
    }

    // can only be called success once, and will bind a sequencer to the contract
    function bindSequencer(address _signer, uint256 _amount, bytes calldata _signerPubKey) external onlyStakingManager {
        require(sequencerId == 0, "StakingPool: sequencer already binded");
        require(_signer != address(0), "StakingPool: invalid signer");
        require(_signerPubKey.length > 0, "StakingPool: invalid signer pub key");
        require(_amount >= lockingPool.minLock() && _amount <= lockingPool.maxLock(), "StakingPool: invalid amount");

        IERC20(l1Token).safeTransferFrom(msg.sender, address(this), _amount);

        IERC20(l1Token).safeApprove(address(lockingPool), _amount);
        lockingPool.lockFor(_signer, _amount, _signerPubKey);
        sequencerId = lockingPool.getSequencerId(_signer);
        lockingPool.setSequencerRewardRecipient(sequencerId, rewardRecipient);
        signer = _signer;

        emit SequencerBound(_signer, _amount, _signerPubKey, sequencerId);
    }

    function increaseStakingAmount(uint256 _amount) external onlyStakingManager {
        require(_amount > 0, "StakingPool: invalid amount");
        require(canStake(_amount), "StakingPool: exceed max lock");
        IERC20(l1Token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(l1Token).safeApprove(address(lockingPool), _amount);
        lockingPool.relock(sequencerId, _amount, false);
        emit StakingAmountIncreased(_amount);
    }

    function claimRewards() external onlyStakingManager {
        uint256 _rewards = lockingPool.sequencerReward(sequencerId);
        lockingPool.withdrawRewards(sequencerId, 0);
        emit RewardsClaimed(_rewards);
    }

    function stakingAmount() public view returns (uint256) {
        return lockingPool.sequencerLock(sequencerId);
    }

    function canStake(uint256 _amount) public view returns (bool) {
        return _amount + lockingPool.sequencerLock(sequencerId) <= lockingPool.maxLock();
    }
}