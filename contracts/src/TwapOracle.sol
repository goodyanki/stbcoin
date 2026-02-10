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

    function setPublisher(address publisher, bool allowed) external onlyOwner {
        isPublisher[publisher] = allowed;
        emit PublisherSet(publisher, allowed);
    }

    function updateTwap(uint256 priceE18) external onlyPublisher {
        if (priceE18 == 0) revert InvalidPrice();
        twapPriceE18 = priceE18;
        updatedAt = block.timestamp;
        emit TwapUpdated(priceE18, block.timestamp);
    }

    function getTwap() external view returns (uint256 priceE18, uint256 timestamp) {
        return (twapPriceE18, updatedAt);
    }
}

