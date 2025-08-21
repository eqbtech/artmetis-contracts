// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IUniversalRouter} from "../Interfaces/IUniversalRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/TestContracts/ERC20Mock.sol";

contract MockUniversalRouter is IUniversalRouter {
    ERC20Mock public token;

    constructor(address _token) {
        // Constructor can be used for initialization if needed
        token = ERC20Mock(_token);
    }

    function setToken(address _token) external {
        token = ERC20Mock(_token);
    }

    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable {
        token.mint(msg.sender, 2 * msg.value);
    }
}
