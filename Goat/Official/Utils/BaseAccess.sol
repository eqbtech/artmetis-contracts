// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Executor} from "./Executor.sol";

contract BaseAccess {
    error AccessDenied();
    error Forbidden();

    modifier OnlyRelayer() {
        if (msg.sender != Executor.Relayer) {
            revert AccessDenied();
        }
        _;
    }

    modifier OnlyLockingExecutor() {
        if (msg.sender != Executor.Locking) {
            revert AccessDenied();
        }
        _;
    }
}
