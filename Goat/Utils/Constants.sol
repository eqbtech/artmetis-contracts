// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Constants {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // address
    bytes32 public constant REWARD_RECIPIENT = keccak256("REWARD_RECIPIENT");

    // Contracts
    bytes32 public constant GOAT_TOKEN = keccak256("GOAT_TOKEN");
    bytes32 public constant ART_GOAT = keccak256("ART_GOAT");
    bytes32 public constant ART_BTC = keccak256("ART_BTC");

    bytes32 public constant SEQUENCER_LOCKING_POOL_MANAGER =
        keccak256("SEQUENCER_LOCKING_POOL_MANAGER");
    bytes32 public constant REWARD_POOL = keccak256("REWARD_POOL");
    bytes32 public constant WITHDRAWAL_RECIPIENT =
        keccak256("WITHDRAWAL_RECIPIENT");
}
