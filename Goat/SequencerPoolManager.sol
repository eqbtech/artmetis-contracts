// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./Interfaces/ISequencerPoolManager.sol";
import "./Interfaces/ISequencerPool.sol";
import "./Interfaces/IRewardDistributor.sol";
import "./Utils/Constants.sol";
import "./Interfaces/IGoatConfig.sol";

contract SequencerPoolManager is
    ISequencerPoolManager,
    AccessControlUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    address public config;
    address public locking;
    address public sequencerPoolBeaconProxy;
    address public distributorBeaconProxy;
    EnumerableSet.AddressSet private pools;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _config,
        address _locking,
        address _sequencerPoolBeaconProxy,
        address _distributorBeaconProxy
    ) public initializer {
        __AccessControl_init();

        require(_config != address(0), "SequencerPoolManager: INVALID_CONFIG");
        require(
            _locking != address(0),
            "SequencerPoolManager: INVALID_LOCKING"
        );
        require(
            _sequencerPoolBeaconProxy != address(0),
            "SequencerPoolManager: INVALID_SEQUENCER_POOL_BEACON_PROXY"
        );
        require(
            _distributorBeaconProxy != address(0),
            "SequencerPoolManager: INVALID_DISTRIBUTOR_BEACON_PROXY"
        );

        config = _config;
        locking = _locking;
        sequencerPoolBeaconProxy = _sequencerPoolBeaconProxy;
        distributorBeaconProxy = _distributorBeaconProxy;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.ADMIN_ROLE, msg.sender);

        emit InitializedSet(
            _config,
            _locking,
            _sequencerPoolBeaconProxy,
            _distributorBeaconProxy
        );
    }

    function createPool(
        uint256 _feeRate,
        uint256 _feeShare,
        uint256 _extraShare
    ) external override onlyRole(Constants.ADMIN_ROLE) {
        BeaconProxy _sequencerPool = new BeaconProxy(
            sequencerPoolBeaconProxy,
            abi.encodeWithSelector(
                ISequencerPool.initialize.selector,
                msg.sender,
                locking,
                config
            )
        );

        BeaconProxy _distributor = new BeaconProxy(
            distributorBeaconProxy,
            abi.encodeWithSelector(
                IRewardDistributor.initialize.selector,
                msg.sender,
                config,
                address(_sequencerPool)
            )
        );
        IRewardDistributor(address(_distributor)).setParams(
            _feeRate,
            _feeShare,
            _extraShare
        );
        ISequencerPool(address(_sequencerPool)).setDistributor(
            address(_distributor)
        );

        pools.add(address(_sequencerPool));

        IGoatConfig(config).addDistributor(address(_distributor));

        emit PoolCreated(address(_sequencerPool), address(_distributor));
    }

    function addPool(
        address _pool
    ) external override onlyRole(Constants.ADMIN_ROLE) {
        require(_pool != address(0), "SequencerPoolManager: INVALID_POOL");
        require(!pools.contains(_pool), "SequencerPoolManager: POOL_EXISTS");
        pools.add(_pool);
        emit PoolAdded(_pool);
    }

    function removePool(
        address _pool
    ) external override onlyRole(Constants.ADMIN_ROLE) {
        require(_pool != address(0), "SequencerPoolManager: INVALID_POOL");
        require(pools.contains(_pool), "SequencerPoolManager: POOL_NOT_EXISTS");
        pools.remove(_pool);
        emit PoolRemoved(_pool);
    }

    function getPool(uint256 _index) external view override returns (address) {
        return pools.at(_index);
    }

    function getPoolCount() external view override returns (uint256) {
        return pools.length();
    }

    function isValidPool(address _pool) external view override returns (bool) {
        return pools.contains(_pool);
    }

    receive() external payable {}
}
