// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRewardReceiver {
    function addReward(address _token, uint256 _amount) external payable;
}
