// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IPermit2} from "../Interfaces/IPermit2.sol";

contract MockPermit is IPermit2 {
    constructor() {
    }


    function approve(address token, address spender, uint160 amount, uint48 expiration) external {}
}
