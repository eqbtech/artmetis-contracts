// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAMTRewardPool {
    function claimReward() external returns (uint256);

    event RewardClaimed(address indexed _user, uint256 _amount);
    event FeeSent(address indexed _feeReceiver, uint256 _feeAmount);
    event FeeReceiverSet(address _feeReceiver);
    event FeeRateSet(uint256 _feeRate);
}
