// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Utils/Constants.sol";
import "./Interfaces/IWithdrawalRecipient.sol";
import "./Interfaces/IGoatConfig.sol";
import "./GoatAccessController.sol";

contract WithdrawalRecipient is
    GoatAccessController,
    IWithdrawalRecipient,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using TransferHelper for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) public initializer {
        __AccessControl_init();

        require(_config != address(0), "WithdrawalRecipient: INVALID_CONFIG");
        __GoatControl_init(_config);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.ADMIN_ROLE, msg.sender);
    }

    function withdraw(
        address _token,
        uint256 _amount
    ) external onlyWithdrawalManager {
        require(_amount > 0, "WithdrawalRecipient: INVALID_AMOUNT");
        uint256 _balance = address(_token).balanceOf(address(this));
        require(_balance >= _amount, "amount exceeds balance");
        address(_token).safeTransferToken(msg.sender, _amount);

        emit Withdrawn(msg.sender, _token, _amount);
    }

    receive() external payable {}
}
