// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockAggregatorV3 {
    uint8 public immutable decimals;
    int256 public answer;
    uint256 public updatedAt;

    constructor(uint8 feedDecimals, int256 initialAnswer) {
        decimals = feedDecimals;
        answer = initialAnswer;
        updatedAt = block.timestamp;
    }

    function setAnswer(int256 nextAnswer) external {
        answer = nextAnswer;
        updatedAt = block.timestamp;
    }

    function setAnswerWithTimestamp(int256 nextAnswer, uint256 nextUpdatedAt) external {
        answer = nextAnswer;
        updatedAt = nextUpdatedAt;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}

