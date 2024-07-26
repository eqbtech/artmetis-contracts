// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./Interfaces/IStakingPoolManager.sol";
import "./Interfaces/IStakingPool.sol";
import "../Utils/AMTConstants.sol";

contract StakingPoolManager is IStakingPoolManager, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private pools;
    address public l1Token;
    address public stakingPoolBeaconProxy;
    address public lockingPool;
    address public rewardRecipient;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _l1Token) public initializer {
        require(_l1Token != address(0), "StakingPoolManager: invalid l1 token");

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);

        l1Token = _l1Token;
    }

    function setParams(
        address _stakingPoolBeaconProxy,
        address _lockingPool,
        address _rewardRecipient
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(
            _stakingPoolBeaconProxy != address(0),
            "StakingPoolManager: invalid staking pool beacon proxy"
        );
        require(
            _lockingPool != address(0),
            "StakingPoolManager: invalid locking pool"
        );
        require(
            _rewardRecipient != address(0),
            "StakingPoolManager: invalid reward recipient"
        );

        stakingPoolBeaconProxy = _stakingPoolBeaconProxy;
        lockingPool = _lockingPool;
        rewardRecipient = _rewardRecipient;
    }

    function createPool() external onlyRole(AMTConstants.ADMIN_ROLE) {
        BeaconProxy _stakingPool = new BeaconProxy(
            stakingPoolBeaconProxy,
            abi.encodeWithSelector(
                IStakingPool.initialize.selector,
                msg.sender,
                lockingPool,
                l1Token,
                rewardRecipient,
                address(this)
            )
        );
        pools.add(address(_stakingPool));

        emit PoolAdded(address(_stakingPool));
    }

    function addPool(address _pool) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(
            !pools.contains(_pool),
            "StakingPoolManager: pool already exists"
        );
        pools.add(_pool);
        emit PoolAdded(_pool);
    }

    function bindSequencerFor(
        address _pool,
        address _signer,
        bytes calldata _signerPubKey
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.contains(_pool), "StakingPoolManager: pool not exists");
        uint256 _amount = IERC20(l1Token).balanceOf(address(this));
        IERC20(l1Token).safeApprove(_pool, _amount);
        IStakingPool(_pool).bindSequencer(_signer, _amount, _signerPubKey);
        emit SequencerBound(_pool, _signer, _amount, _signerPubKey);
    }

    function removePool(
        address _pool
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.contains(_pool), "StakingPoolManager: pool not exists");
        pools.remove(_pool);
        emit PoolRemoved(_pool);
    }

    function stake(
        address _pool,
        uint256 _amount
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.contains(_pool), "StakingPoolManager: pool not exists");
        if (_amount == 0) {
            return;
        }
        IStakingPool _stakingPool = IStakingPool(_pool);
        require(
            _stakingPool.canStake(_amount),
            "StakingPoolManager: cannot stake"
        );

        IERC20(l1Token).safeApprove(_pool, _amount);
        _stakingPool.increaseStakingAmount(_amount);
        emit StakingAmountIncreased(_pool, _amount);
    }

    function withdraw(
        address _pool,
        address _recipient,
        uint256 _amount
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.contains(_pool), "StakingPoolManager: pool not exists");
        if (_amount == 0) {
            return;
        }
        IStakingPool(_pool).withdrawStakingAmount(_recipient, _amount);
        emit StakingAmountWithdrawn(_pool, _recipient, _amount);
    }

    function claimRewards(
        uint32 _l2GasLimit
    ) external payable onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.length() > 0, "StakingPoolManager: no pools");
        for (uint256 i = 0; i < pools.length(); i++) {
            IStakingPool _stakingPool = IStakingPool(pools.at(i));
            _stakingPool.claimRewards{value: msg.value / pools.length()}(_l2GasLimit);
        }
    }

    function getPoolCount() external view returns (uint256) {
        return pools.length();
    }

    function getPool(uint256 _index) external view returns (address) {
        return pools.at(_index);
    }

    function getRewardRecipient(address _pool) external view returns (address) {
        return IStakingPool(_pool).rewardRecipient();
    }

    function getStakingAmount(address _pool) external view returns (uint256) {
        return IStakingPool(_pool).stakingAmount();
    }

    function getRewards(address _pool) external view returns (uint256) {
        return IStakingPool(_pool).getRewards();
    }
}
