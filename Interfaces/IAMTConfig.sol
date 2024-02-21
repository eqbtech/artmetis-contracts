// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAMTConfig {
    event ContractSet(bytes32 _contractKey, address _contractAddress);

    function setContract(
        bytes32 _contractKey,
        address _contractAddress
    ) external;

    function getContract(
        bytes32 _contractKey
    ) external view returns (address);
}

