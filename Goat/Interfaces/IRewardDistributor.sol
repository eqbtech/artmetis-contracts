// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRewardDistributor {
    event InitializedSet(
        address _config,
        address _sequencerPool,
        address rewardPool,
        address goat
    );
    event ParamsSet(
        address indexed _user,
        uint256 _feeRate,
        uint256 _feeShare,
        uint256 _extraShare
    );
    event FeeRateSet(address indexed _user, uint256 _feeRate);
    event ExtraShareSet(address indexed _user, uint256 _extraShare);
    event FeeShareSet(address indexed _user, uint256 _feeShare);
    event RewardDistributed(
        address indexed _pool,
        address indexed _user,
        address _token,
        uint256 _amount
    );

    function initialize(
        address _owner,
        address _config,
        address _sequencerPool
    ) external;

    function setParams(
        uint256 _feeRate,
        uint256 _feeShare,
        uint256 _extraShare
    ) external;

    function distributeReward() external;
}
