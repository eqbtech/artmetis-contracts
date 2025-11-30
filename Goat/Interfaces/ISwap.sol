// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISwap {
    struct Router {
        address from;
        address to;
        bytes commands;
        bytes path;
    }

    event InitializedSet(address indexed _universalRouter, address indexed _permit2);
    event RouterSet(
        address indexed from,
        address indexed to,
        bytes commands,
        bytes path
    );
    event Swapped(
        address indexed from,
        address indexed to,
        uint256 amountIn,
        uint256 amountOut
    );

    function initialize(address _universalRouter, address _permit) external;

    function setRouter(address from, address to, bytes calldata commands, bytes calldata path) external;

    function swap(address from, address to, uint256 _amount) external payable returns (uint256);
}
