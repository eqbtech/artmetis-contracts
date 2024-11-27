// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGoatAssetManager {
    function addPoolBeacon(
        address _asset,
        uint256 _tokenWeight,
        address[] calldata _rewardTokens
    ) external;

    event InitializedSet(
        address _config,
        address _artTokenBeaconProxy,
        address _depositPoolBeaconProxy,
        address _withdrawalManagerBeaconProxy,
        address _baseRewardPoolBeaconProxy
    );
    event PoolBeaconAdded(
        address _asset,
        address _artToken,
        address _depositPool,
        address _withdrawalManager,
        address _baseRewardPool
    );
}
