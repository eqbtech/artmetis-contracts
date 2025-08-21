// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Interfaces/IPermit2.sol";
import "./Interfaces/ISwap.sol";
import "./Interfaces/IUniversalRouter.sol";
import "./Utils/Constants.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";

contract Swap is ISwap, AccessControlUpgradeable {
    using TransferHelper for address;
    using SafeERC20 for IERC20;

    // This address is used to represent the contract itself in certain operations
    address internal constant ADDRESS_THIS = address(2);

    IUniversalRouter public universalRouter;
    IPermit2 public permit2;

    mapping(bytes32 => Router) public routers;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _universalRouter, address _permit2) external initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(Constants.ADMIN_ROLE, msg.sender);

        require(_universalRouter != address(0), "Swap: INVALID_ROUTER");
        require(_permit2 != address(0), "Swap: INVALID_PERMIT2");
        universalRouter = IUniversalRouter(_universalRouter);
        permit2 = IPermit2(_permit2);

        emit InitializedSet(_universalRouter, _permit2);
    }

    function setRouter(
        address from,
        address to,
        bytes calldata commands,
        bytes calldata path
    ) external override onlyRole(Constants.ADMIN_ROLE) {
        require(from != address(0), "Swap: INVALID_FROM_ADDRESS");
        require(to != address(0), "Swap: INVALID_TO_ADDRESS");
        require(commands.length == 2 || commands.length == 1, "Swap: COMMANDS_REQUIRED");
        require(path.length > 0, "Swap: PATH_REQUIRED");

        bytes32 key = keccak256(abi.encodePacked(from, to));
        routers[key] = Router({
            from: from,
            to: to,
            commands: commands,
            path: path
        });

        emit RouterSet(from, to, commands, path);
    }

    function swap(
        address from,
        address to,
        uint256 _amount
    ) external payable override returns (uint256) {
        require(from != address(0), "Swap: INVALID_FROM_ADDRESS");
        require(to != address(0), "Swap: INVALID_TO_ADDRESS");
        require(_amount > 0, "Swap: INVALID_AMOUNT");

        bytes32 key = keccak256(abi.encodePacked(from, to));
        Router storage router = routers[key];
        require(router.from != address(0), "Swap: ROUTER_NOT_FOUND");

        bytes[] memory inputs = new bytes[](router.commands.length);
        uint256 _ethAmount = 0;
        uint256 _index = 0;
        bool payerIsUser = false;
        if (!AddressLib.isPlatformToken(from)) {
            // If 'from' is not a platform token, transfer the tokens from the user to this contract
            IERC20(from).safeTransferFrom(msg.sender, address(this), _amount);
            // Approve the Permit2 contract to spend the tokens
            IERC20(from).approve(address(permit2), _amount);
            permit2.approve(from, address(universalRouter), uint160(_amount), uint48(block.timestamp + 3000));
            payerIsUser = true;
        } else {
            require(msg.value == _amount, "Swap: INVALID_AMOUNT");
            _ethAmount = _amount;
            inputs[0] = abi.encode(ADDRESS_THIS, _amount);
            _index = 1;
        }
        inputs[_index] = abi.encode(
            address(this), // the recipient of the swapped tokens
            _amount,
            0,
            router.path,
            payerIsUser
        );

        uint256 _tokenBalanceBefore = address(to).balanceOf(address(this));
        universalRouter.execute{value: _ethAmount}(router.commands, inputs, block.timestamp + 3000);
        uint256 swappedAmount = address(to).balanceOf(address(this)) - _tokenBalanceBefore;

        // send back the swapped tokens to the caller
        address(to).safeTransferToken(msg.sender, swappedAmount);

        emit Swapped(from, to, _amount, swappedAmount);
        return swappedAmount;
    }
}