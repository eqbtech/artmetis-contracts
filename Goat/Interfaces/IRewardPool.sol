// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IRewardReceiver.sol";

interface IRewardPool {
    function claimAll() external;
    function addReward(
        address _user,
        address _token,
        uint256 _amount
    ) external payable;

    event InitializedSet(address indexed _goatToken);
    event Claimed(
        address indexed _user,
        uint256 _btcAmount,
        uint256 _goatAmount
    );
    event RewardAdded(address indexed _user, address _token, uint256 _amount);
}
