// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library AMTConstants {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Contracts
    bytes32 public constant ART_METIS = keccak256("ART_METIS");
    bytes32 public constant AMT_REWARD_POOL = keccak256("AMT_REWARD_POOL");
    bytes32 public constant AMT_DEPOSIT_POOL = keccak256("AMT_DEPOSIT_POOL");
    bytes32 public constant METIS = keccak256("METIS");
    bytes32 public constant L1_STAKING_POOL = keccak256("L1_STAKING_POOL");
    bytes32 public constant AMT_WITHDRAWAL_MANAGER = keccak256("AMT_WITHDRAWAL_MANAGER");
}
