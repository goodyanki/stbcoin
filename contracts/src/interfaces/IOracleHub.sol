// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOracleHub {
    function getValidatedPrice() external view returns (uint256);

    function setConfig(uint256 newSpotMaxAge, uint256 newTwapMaxAge, uint256 newMaxDeviationBps)
        external;

    function setDemoMode(bool enabled) external;

    function setDemoPrice(uint256 priceE18) external;

    function getPriceStatus()
        external
        view
        returns (
            uint256 effectivePrice,
            uint256 spotPrice,
            uint256 twapPrice,
            uint256 spotUpdatedAt,
            uint256 twapUpdatedAt,
            bool breakerTriggered
        );

    function canRiskActionProceed() external view returns (bool);
}
