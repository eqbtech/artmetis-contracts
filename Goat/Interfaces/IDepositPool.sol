// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IRewardReceiver.sol";

interface IDepositPool is IRewardReceiver {
    function initialize(
        address _owner,
        address _config,
        address _token,
        address _artToken
    ) external;

    function getArtTokenAmountToMint(
        uint256 _amount
    ) external view returns (uint256);

    function deposit(
        address _pool,
        uint256 _amount,
        uint256 _minArtBTCAmountToReceive,
        string calldata _referralId
    ) external payable returns (uint256);

    function initiateWithdrawalFor(
        address _pool,
        address _user,
        uint256 _artAmount
    ) external returns (uint256);

    event InitializedSet(address _token, address indexed _artToken);
    event Deposited(
        address indexed _pool,
        address indexed _user,
        uint256 _amount,
        uint256 _artTokenAmount,
        string _referralId
    );
    event PartnerDeposited(
        address indexed _pool,
        address indexed _user,
        uint256 _amount
    );
    event Harvested(address indexed _user, uint256 _amount);
    event RewardAdded(uint256 _amount);
    event InitiateWithdrawalFor(
        address _token,
        address indexed _user,
        uint256 _artAmount,
        uint256 _amount
    );
}
