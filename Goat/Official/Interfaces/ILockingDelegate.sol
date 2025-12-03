// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILocking} from "./ILocking.sol";

interface ILockingDelegate {
    function delegate(
        address validator,
        ILocking.Locking[] calldata values
    ) external payable;

    function undelegate(
        address validator,
        address recipient,
        ILocking.Locking[] calldata values
    ) external;

    function claimRewards(address validator) external;

    function underlying() external view returns (ILocking);

    function migrate(
        address validator,
        address operator,
        address funderPayee,
        address funder,
        uint256 operatorNativeAllowance,
        uint256 operatorTokenAllowance,
        uint256 allowanceUpdatePeriod
    ) external;
}
