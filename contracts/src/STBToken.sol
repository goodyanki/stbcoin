// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "./interfaces/IERC20.sol";
import { Ownable } from "./utils/Ownable.sol";

contract STBToken is IERC20, Ownable {
    string public constant name = "StableVault USD";
    string public constant symbol = "STB";
    uint8 public constant decimals = 18;

    uint256 public override totalSupply;
    address public vault;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    error NotVault(address caller);
    error ZeroAddress();

    event VaultSet(address indexed vaultAddress);

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault(msg.sender);
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Sets the authorized vault contract that can mint/burn STB.
    /// @dev Callable only by owner. Reverts on zero address.
    /// @param vaultAddress Address of StableVault contract.
    function setVault(address vaultAddress) external onlyOwner {
        if (vaultAddress == address(0)) revert ZeroAddress();
        vault = vaultAddress;
        emit VaultSet(vaultAddress);
    }

    /// @notice Transfers STB from caller to recipient.
    /// @param to Recipient address.
    /// @param amount Amount of STB to transfer.
    /// @return True when transfer succeeds.
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Approves a spender to spend caller's STB.
    /// @param spender Address allowed to spend tokens.
    /// @param amount Allowance amount.
    /// @return True when approval succeeds.
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens using an existing allowance.
    /// @dev Decreases allowance unless it is set to max uint256.
    /// @param from Token owner address.
    /// @param to Recipient address.
    /// @param amount Amount to transfer.
    /// @return True when transfer succeeds.
    function transferFrom(address from, address to, uint256 amount)
        external
        override
        returns (bool)
    {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ALLOWANCE");
            allowance[from][msg.sender] = currentAllowance - amount;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, amount);
        return true;
    }

    /// @notice Mints STB to a recipient.
    /// @dev Callable only by configured vault.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external onlyVault {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Burns STB from an account.
    /// @dev Callable only by configured vault.
    /// @param from Address whose tokens are burned.
    /// @param amount Amount to burn.
    function burn(address from, uint256 amount) external onlyVault {
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "BALANCE");
        balanceOf[from] = fromBalance - amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "BALANCE");
        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
