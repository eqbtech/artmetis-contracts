// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVester {

    event MetisAdded(address indexed user, uint256 amount);
    event VestingPositionAdded(address indexed user, uint256 amount, uint256 durationWeeks, uint256 start, uint256 vestId);
    event VestingPositionClosed(address indexed user, uint256 amount, uint256 vestId, uint256 usdtAmount);
    event Withdrawn(address indexed user, uint256 usdtAmount, uint256 amount);

    struct VestingPosition {
        address user;
        uint256 amount;
        uint256 durationWeeks;
        uint256 start;
        bool closed;
    }

    function addMetis(uint256 _amount) external payable;

    function vest(uint256 _amount, uint256 _weeks) external;

    function closeVestingPosition(uint256 _vestId, uint256 _maxAmount) external;

    function withdraw(uint256 _amount) external;

    function getVestingPosition(uint256 _vestId) external view returns (VestingPosition memory);

    function getUserVestingPositions(address _user) external view returns (uint256[] memory);

    function calculateVestingAmount(uint256 _amount, uint256 _weeks) external view returns (uint256);
}
