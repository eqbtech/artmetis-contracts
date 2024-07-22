// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAMTDepositPool {
    function getArtMetisAmountToMint(
        uint256 _amount
    ) external view returns (uint256);

    function deposit(
        uint256 _minArtMetisAmountToReceive,
        string calldata _referralId
    ) external payable returns (uint256);

    function harvest() external;

    function bridgeMetisToL1(uint32 l1Gas) external payable;

    function adminWithdrawMetis(uint256 _amount) external;

    function initiateWithdrawalFor(
        address _user,
        uint256 _artMetisAmount,
        uint256 _depositAmount
    ) external;

    event MetisDeposited(
        address indexed _user,
        uint256 _amount,
        uint256 _artMetisAmount,
        string _referralId
    );
    event Harvested(address indexed _user, uint256 _amount);
    event BridgeMetisToL1(address indexed _user, uint256 _amount);
    event AdminWithdrawnMetis(address indexed _user, uint256 _amount);
    event InitiateWithdrawalFor(
        address indexed _user,
        uint256 _artMetisAmount,
        uint256 _depositAmount
    );
}
