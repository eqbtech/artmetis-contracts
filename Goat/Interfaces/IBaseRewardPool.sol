// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IRewardReceiver.sol";

interface IBaseRewardPool is IRewardReceiver {
    event InitializedSet(address _artToken, address[] _rewardTokens);
    event Staked(address _user, uint256 _amount);
    event Withdrawn(address _account, uint256 _amount);
    event RewardPaid(address _account, address _rewardToken, uint256 _reward);
    event RewardAdded(address _rewardToken, uint256 _rewards);

    function initialize(
        address _owner,
        address _config,
        address _stakingToken,
        address[] calldata _rewardTokens
    ) external;

    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function earned(
        address _account,
        address _rewardToken
    ) external view returns (uint256);

    function claimReward() external;
}
