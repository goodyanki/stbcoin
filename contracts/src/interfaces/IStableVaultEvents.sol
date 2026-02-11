// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStableVaultEvents {
    event Deposited(address indexed owner, uint256 ethAmount);
    event Withdrawn(address indexed owner, uint256 ethAmount);
    event Minted(address indexed owner, uint256 stbAmount);
    event Repaid(address indexed owner, uint256 stbAmount, uint256 feePaid, uint256 principalPaid);
    event Liquidated(
        address indexed owner,
        address indexed liquidator,
        uint256 repayAmount,
        uint256 seizedCollateral,
        uint256 badDebtDelta
    );
}
