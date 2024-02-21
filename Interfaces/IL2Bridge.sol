// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IL2Bridge {
    function withdrawMetisTo(address _to, uint256 _amount, uint32 _l1Gas, bytes calldata _data) external payable;
}

