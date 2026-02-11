// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IAggregatorV3 } from "./interfaces/IAggregatorV3.sol";
import { Ownable } from "./utils/Ownable.sol";
import { TwapOracle } from "./TwapOracle.sol";

contract OracleHub is Ownable {
    IAggregatorV3 public immutable chainlinkEthUsd;
    TwapOracle public immutable twapOracle;

    uint256 public spotMaxAge = 3600;
    uint256 public twapMaxAge = 600;
    uint256 public maxDeviationBps = 1200;
    bool public demoMode;
    uint256 public demoPriceE18;

    error InvalidPrice();

    event OracleConfigUpdated(uint256 spotMaxAge, uint256 twapMaxAge, uint256 maxDeviationBps);
    event DemoModeSet(bool enabled);
    event DemoPriceSet(uint256 demoPriceE18);

    constructor(address initialOwner, address chainlinkFeed, address twapOracleAddress)
        Ownable(initialOwner)
    {
        chainlinkEthUsd = IAggregatorV3(chainlinkFeed);
        twapOracle = TwapOracle(twapOracleAddress);
    }

    /// @notice Updates oracle breaker configuration thresholds.
    /// @dev Callable only by owner.
    /// @param newSpotMaxAge Maximum age for spot price in seconds.
    /// @param newTwapMaxAge Maximum age for TWAP price in seconds.
    /// @param newMaxDeviationBps Maximum allowed spot/TWAP deviation in bps.
    function setConfig(uint256 newSpotMaxAge, uint256 newTwapMaxAge, uint256 newMaxDeviationBps)
        external
        onlyOwner
    {
        spotMaxAge = newSpotMaxAge;
        twapMaxAge = newTwapMaxAge;
        maxDeviationBps = newMaxDeviationBps;
        emit OracleConfigUpdated(newSpotMaxAge, newTwapMaxAge, newMaxDeviationBps);
    }

    /// @notice Enables or disables demo pricing mode.
    /// @dev Callable only by owner.
    /// @param enabled True to use demo price, false to use real oracles.
    function setDemoMode(bool enabled) external onlyOwner {
        demoMode = enabled;
        emit DemoModeSet(enabled);
    }

    /// @notice Sets manual demo ETH price used when demo mode is enabled.
    /// @dev Reverts if demo mode is disabled or price is zero.
    /// @param priceE18 Demo ETH/USD price in 1e18 precision.
    function setDemoPrice(uint256 priceE18) external onlyOwner {
        if (!demoMode) revert InvalidPrice();
        if (priceE18 == 0) revert InvalidPrice();
        demoPriceE18 = priceE18;
        emit DemoPriceSet(priceE18);
    }

    /// @notice Returns validated effective ETH price.
    /// @dev Reverts when breaker is triggered.
    /// @return Effective ETH/USD price in 1e18 precision.
    function getValidatedPrice() external view returns (uint256) {
        (uint256 effectivePrice,,,,, bool breakerTriggered) = getPriceStatus();
        if (breakerTriggered) revert InvalidPrice();
        return effectivePrice;
    }

    /// @notice Indicates whether risky actions are currently allowed.
    /// @return True if breaker is not triggered, false otherwise.
    function canRiskActionProceed() external view returns (bool) {
        (,,,,, bool breakerTriggered) = getPriceStatus();
        return !breakerTriggered;
    }

    /// @notice Returns current oracle status used by risk checks.
    /// @dev If demo mode is active, all returned prices are the demo price.
    /// @return effectivePrice Effective ETH/USD price used by protocol logic.
    /// @return spotPrice Spot price from Chainlink feed (1e18).
    /// @return twapPrice TWAP price from TwapOracle (1e18).
    /// @return spotUpdatedAt Spot price timestamp.
    /// @return twapUpdatedAt TWAP price timestamp.
    /// @return breakerTriggered True when stale/deviated data triggers breaker.
    function getPriceStatus()
        public
        view
        returns (
            uint256 effectivePrice,
            uint256 spotPrice,
            uint256 twapPrice,
            uint256 spotUpdatedAt,
            uint256 twapUpdatedAt,
            bool breakerTriggered
        )
    {
        if (demoMode && demoPriceE18 > 0) {
            return
                (demoPriceE18, demoPriceE18, demoPriceE18, block.timestamp, block.timestamp, false);
        }

        (spotPrice, spotUpdatedAt) = _readChainlinkE18();
        (twapPrice, twapUpdatedAt) = twapOracle.getTwap();

        bool spotStale =
            spotUpdatedAt > block.timestamp || (block.timestamp - spotUpdatedAt > spotMaxAge);
        bool twapStale =
            twapUpdatedAt > block.timestamp || (block.timestamp - twapUpdatedAt > twapMaxAge);

        if (spotStale || twapStale || twapPrice == 0) {
            return (spotPrice, spotPrice, twapPrice, spotUpdatedAt, twapUpdatedAt, true);
        }

        uint256 diff = spotPrice > twapPrice ? spotPrice - twapPrice : twapPrice - spotPrice;
        uint256 deviationBps = (diff * 10_000) / twapPrice;
        breakerTriggered = deviationBps > maxDeviationBps;

        effectivePrice = spotPrice;
    }

    function _readChainlinkE18() internal view returns (uint256 priceE18, uint256 updatedAt) {
        (, int256 answer,, uint256 timestamp,) = chainlinkEthUsd.latestRoundData();
        if (answer <= 0) revert InvalidPrice();

        uint8 feedDecimals = chainlinkEthUsd.decimals();
        uint256 rawPrice = uint256(answer);

        if (feedDecimals == 18) {
            priceE18 = rawPrice;
        } else if (feedDecimals < 18) {
            priceE18 = rawPrice * (10 ** (18 - feedDecimals));
        } else {
            priceE18 = rawPrice / (10 ** (feedDecimals - 18));
        }

        updatedAt = timestamp;
    }
}
