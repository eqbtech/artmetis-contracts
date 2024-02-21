// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Interfaces/IStakingPoolManager.sol";
import "./Interfaces/IStakingPool.sol";
import "../Utils/AMTConstants.sol";

contract StakingPoolManager is IStakingPoolManager, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private pools;
    address public l1Token;

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

    function addPool(address _pool) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(!pools.contains(_pool), "StakingPoolManager: pool already exists");
        pools.add(_pool);
        emit PoolAdded(_pool);
    }

    function bindSequencerFor(address _pool, address _signer, bytes calldata _signerPubKey) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.contains(_pool), "StakingPoolManager: pool not exists");
        uint256 _amount = IERC20(l1Token).balanceOf(address(this));
        IERC20(l1Token).safeApprove(_pool, _amount);
        IStakingPool(_pool).bindSequencer(_signer, _amount, _signerPubKey);
        emit SequencerBound(_pool, _signer, _amount, _signerPubKey);
    }

    function removePool(address _pool) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.contains(_pool), "StakingPoolManager: pool not exists");
        pools.remove(_pool);
        emit PoolRemoved(_pool);
    }

    function stake() external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.length() > 0, "StakingPoolManager: no pools");
        uint256 _amount = IERC20(l1Token).balanceOf(address(this));
        if (_amount == 0) {
            return;
        }
        // TODO: choose a pool to stake
        IStakingPool _stakingPool = IStakingPool(pools.at(pools.length() - 1));
        require(_stakingPool.canStake(_amount), "StakingPoolManager: cannot stake");

        IERC20(l1Token).safeApprove(address(_stakingPool), _amount);
        _stakingPool.increaseStakingAmount(_amount);
        emit StakingAmountIncreased(address(_stakingPool), _amount);
    }

    function claimRewards() external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(pools.length() > 0, "StakingPoolManager: no pools");
        for (uint256 i = 0; i < pools.length(); i++) {
            IStakingPool _stakingPool = IStakingPool(pools.at(i));
            _stakingPool.claimRewards();
        }
    }
}