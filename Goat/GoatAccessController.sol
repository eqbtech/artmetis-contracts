// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Interfaces/IGoatConfig.sol";

abstract contract GoatAccessController is Initializable {
    IGoatConfig public config;

    function __GoatControl_init(address _config) internal onlyInitializing {
        config = IGoatConfig(_config);
    }

    modifier onlyDepositPool() {
        require(
            IGoatConfig(config).isDepositPool(msg.sender),
            "GoatAccessController: only deposit pool"
        );
        _;
    }

    modifier onlySupportedToken(address _token) {
        require(
            config.isSupportedToken(_token),
            "GoatAccessController: unsupported token"
        );
        _;
    }

    modifier onlyWithdrawalManager() {
        require(
            config.isWithdrawalManager(msg.sender),
            "GoatAccessController: only withdrawal manager"
        );
        _;
    }

    modifier onlyDistributor() {
        require(
            config.isDistributor(msg.sender),
            "GoatAccessController: only distributor"
        );
        _;
    }
}
