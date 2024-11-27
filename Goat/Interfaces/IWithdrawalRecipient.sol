// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IWithdrawalRecipient {
    event Withdrawn(address indexed _user, address indexed _token, uint256 _amount);

    function withdraw(address _token, uint256 _amount) external;
}
