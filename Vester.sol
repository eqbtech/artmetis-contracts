// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces/IVester.sol";
import "./Utils/AMTConstants.sol";
import "./Interfaces/IOracle.sol";
import "./Interfaces/IArtMetis.sol";

contract Vester is IVester, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public constant WEEK = 86400 * 7;
    uint256 public constant MIN_WEEK = 2;
    uint256 public constant MAX_WEEK = 40;
    uint256 public expireWeeks;

    address public oMetis;
    address public usdt;
    IOracle public oracle;
    uint256 public discountPerWeek;
    uint256 public constant DISCOUNT_PRECISION = 1e3;
    uint256 public constant PRICE_PRECISION = 1e18;

    // all vesting positions
    VestingPosition[] public vestingPositions;
    // user address => vesting position ids
    mapping(address => uint256[]) public userVestingPositions;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _oMetis, address _usdt, address _oracle) public initializer {
        __AccessControl_init();

        require(_oMetis != address(0), "Vester: invalid _oMetis");
        require(_usdt != address(0), "Vester: invalid _usdt");
        require(_oracle != address(0), "Vester: invalid _oracle");
        oMetis = _oMetis;
        usdt = _usdt;
        oracle = IOracle(_oracle);
        expireWeeks = 4;
        discountPerWeek = 25;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);
    }

    function addMetis(uint256 _amount) external payable onlyRole(AMTConstants.ADMIN_ROLE) {
        require(msg.value == _amount, "Vester: invalid msg.value");
        IArtMetis(oMetis).mint(msg.sender, _amount);
        emit MetisAdded(msg.sender, _amount);
    }

    function vest(uint256 _amount, uint256 _weeks) external override {
        require(_amount > 0, "Vester: invalid _amount");
        require(_weeks >= MIN_WEEK && _weeks <= MAX_WEEK, "Vester: invalid _weeks");

        uint256 vestId = vestingPositions.length;
        vestingPositions.push(VestingPosition({
            user: msg.sender,
            amount: _amount,
            start: block.timestamp,
            durationWeeks : _weeks,
            closed: false
        }));
        userVestingPositions[msg.sender].push(vestId);
        IERC20(oMetis).safeTransferFrom(msg.sender, address(this), _amount);
        emit VestingPositionAdded(msg.sender, _amount, _weeks, block.timestamp, vestId);
    }

    function closeVestingPosition(uint256 _vestId, uint256 _maxAmount) external {
        require(_vestId < vestingPositions.length, "Vester: invalid _vestId");

        VestingPosition storage vestingPosition = vestingPositions[_vestId];
        require(vestingPosition.user == msg.sender, "Vester: invalid user");
        require(_getTimeWeeksAfter(vestingPosition.start, vestingPosition.durationWeeks) < block.timestamp, "Vester: vesting position not matured");
        require(_getTimeWeeksAfter(vestingPosition.start, vestingPosition.durationWeeks + expireWeeks) > block.timestamp, "Vester: vesting position has expired");
        require(!vestingPosition.closed, "Vester: vesting position already closed");

        uint256 _usdtAmount = _calculateVestingAmount(vestingPosition.amount, vestingPosition.durationWeeks);
        require(_usdtAmount <= _maxAmount, "Vester: amount exceeds _maxAmount");
        // close the vesting position
        vestingPosition.closed = true;

        uint256 _amount = vestingPosition.amount;
        IERC20(usdt).safeTransferFrom(msg.sender, address(this), _usdtAmount);
        IArtMetis(oMetis).burn(address(this), _amount);
        TransferHelper.safeTransferETH(msg.sender, _amount);

        emit VestingPositionClosed(msg.sender, _amount, _vestId, _usdtAmount);
    }

    function withdraw(uint256 _amount) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(_amount <= address(this).balance, "Vester: amount exceeds balance");
        uint256 _usdtBalance = IERC20(usdt).balanceOf(address(this));
        if (_usdtBalance > 0) {
            IERC20(usdt).safeTransfer(msg.sender, _usdtBalance);
        }
        if (_amount > 0) {
            TransferHelper.safeTransferETH(msg.sender, _amount);
        }
        emit Withdrawn(msg.sender, _usdtBalance, _amount);
    }

    function calculateVestingAmount(uint256 _amount, uint256 _weeks) external view returns (uint256) {
        return _calculateVestingAmount(_amount, _weeks);
    }

    function _calculateVestingAmount(uint256 _amount, uint256 _weeks) internal view returns (uint256) {
        uint256 discount = _weeks * discountPerWeek;
        uint256 _usdtAmount = _amount * oracle.getPrice() * (DISCOUNT_PRECISION - discount) / DISCOUNT_PRECISION / PRICE_PRECISION;
        return _decimalConvert(_usdtAmount, ERC20(oMetis).decimals(), ERC20(usdt).decimals());
    }

    function _decimalConvert(uint256 _amount, uint8 _from, uint8 _to) internal pure returns (uint256) {
        return _amount * 10 ** _to / 10 ** _from;
    }

    function getVestingPosition(uint256 _vestId) external view returns (VestingPosition memory) {
        return vestingPositions[_vestId];
    }

    function getUserVestingPositions(address _user) external view override returns (uint256[] memory) {
        return userVestingPositions[_user];
    }

    function _getTimeWeeksAfter(uint256 _start, uint256 _weeks) internal pure returns (uint256) {
        return _start + _weeks * WEEK;
    }

    receive() external payable {}
}