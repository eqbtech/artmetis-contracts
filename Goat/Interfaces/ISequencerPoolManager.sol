// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISequencerPoolManager {
    event InitializedSet(
        address _config,
        address _locking,
        address _sequencerPoolBeaconProxy,
        address _distributorBeaconProxy
    );
    event PoolCreated(address indexed _pool, address indexed _distributor);
    event PoolAdded(address indexed _pool);
    event PoolRemoved(address indexed _pool);

    function createPool(
        uint256 _feeRate,
        uint256 _feeShare,
        uint256 _extraShare
    ) external;

    function addPool(address _pool) external;

    function removePool(address _pool) external;

    function getPoolCount() external view returns (uint256);

    function getPool(uint256 _index) external view returns (address);

    function isValidPool(address _pool) external view returns (bool);
}
