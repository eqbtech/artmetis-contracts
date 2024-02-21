// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./Interfaces/IArtMetis.sol";
import "./Utils/AMTConstants.sol";

contract ArtMetis is IArtMetis, ERC20Upgradeable, AccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();

        __ERC20_init_unchained("Staked Metis Token", "artMETIS");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external override onlyRole(AMTConstants.MINTER_ROLE) {
        _mint(_to, _amount);
    }

    function burn(
        address _from,
        uint256 _amount
    ) external override onlyRole(AMTConstants.BURNER_ROLE) {
        _burn(_from, _amount);
    }
}
