// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "./utils/Ownable.sol";

contract TwapOracle is Ownable {
    uint256 public twapPriceE18;
    uint256 public updatedAt;

    mapping(address => bool) public isPublisher;

    error NotPublisher(address caller);
    error InvalidPrice();

    event PublisherSet(address indexed publisher, bool allowed);
    event TwapUpdated(uint256 priceE18, uint256 updatedAt);

    modifier onlyPublisher() {
        if (!isPublisher[msg.sender] && msg.sender != owner) revert NotPublisher(msg.sender);
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Grants or revokes TWAP publish permission.
    /// @dev Callable only by owner.
    /// @param publisher Address to update.
    /// @param allowed True to allow publishing, false to revoke.
    function setPublisher(address publisher, bool allowed) external onlyOwner {
        isPublisher[publisher] = allowed;
        emit PublisherSet(publisher, allowed);
    }

    /// @notice Updates stored TWAP ETH price.
    /// @dev Callable by owner or approved publisher. Price is 1e18-scaled USD value.
    /// @param priceE18 New TWAP price in 1e18 precision.
    function updateTwap(uint256 priceE18) external onlyPublisher {
        if (priceE18 == 0) revert InvalidPrice();
        twapPriceE18 = priceE18;
        updatedAt = block.timestamp;
        emit TwapUpdated(priceE18, block.timestamp);
    }

    /// @notice Returns the latest TWAP price and timestamp.
    /// @return priceE18 TWAP ETH/USD price in 1e18 precision.
    /// @return timestamp Block timestamp when TWAP was last updated.
    function getTwap() external view returns (uint256 priceE18, uint256 timestamp) {
        return (twapPriceE18, updatedAt);
    }
}
