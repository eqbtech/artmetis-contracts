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

    function bridgeMetisToL1() external;

    event MetisDeposited(
        address indexed _user,
        uint256 _amount,
        uint256 _artMetisAmount,
        string _referralId
    );
    event Harvested(address indexed _user, uint256 _amount);
    event BridgeMetisToL1(address indexed _user, uint256 _amount);
}
