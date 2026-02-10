# @version 0.4.3
"""
OracleChainlinkAdapter.vy
- Reads ETH/USD (or any asset/USD) from Chainlink AggregatorV3
- Normalizes price to 1e18 precision
- Enforces staleness (max_age)
- Optional circuit breaker on per-update price jumps (view-time check)
- Exposes get_price() -> uint256 (1e18), aligned with VaultManager.vy

How to use:
- Deploy with:
    feed = Chainlink ETH/USD aggregator address (for your target network)
    max_age = e.g. 3600 (1 hour) or 0 to disable
    max_change_bps = e.g. 2000 (20%) or 0 to disable
    owner = admin (can pause / change params if desired)

- Point VaultManager._oracle to this adapter address.

Security notes:
- latestRoundData() returns:
    roundId, answer, startedAt, updatedAt, answeredInRound
- We require:
    answer > 0
    updatedAt != 0
    answeredInRound >= roundId (standard Chainlink freshness check)
    block.timestamp - updatedAt <= max_age (if enabled)
"""

event Paused:
    is_paused: bool

event ParamsUpdated:
    max_age: uint256
    max_change_bps: uint256

event OwnershipTransferred:
    old_owner: address
    new_owner: address

event FeedUpdated:
    old_feed: address
    new_feed: address


# -------------------------
# Chainlink interface
# -------------------------
interface AggregatorV3Interface:
    def decimals() -> uint8: view
    def latestRoundData() -> (uint80, int256, uint256, uint256, uint80): view
    # roundId, answer, startedAt, updatedAt, answeredInRound


# -------------------------
# Storage
# -------------------------
feed: public(address)
feed_decimals: public(uint256)

owner: public(address)
paused: public(bool)

# Staleness threshold (seconds). 0 disables.
max_age: public(uint256)

# Circuit breaker (basis points). 0 disables.
# In a pure view adapter, we can only check change vs a stored last_price.
max_change_bps: public(uint256)
last_price_1e18: public(uint256)
last_update_time: public(uint256)

BPS: constant(uint256) = 10_000
PRICE_PRECISION: constant(uint256) = 10**18


# -------------------------
# Constructor
# -------------------------
@deploy
def __init__(_feed: address, _max_age: uint256, _max_change_bps: uint256, _owner: address):
    assert _feed != empty(address), "feed=0"
    assert _owner != empty(address), "owner=0"
    assert _max_change_bps <= BPS, "bps too high"

    self.feed = _feed
    self.feed_decimals = convert(staticcall AggregatorV3Interface(_feed).decimals(), uint256)

    self.max_age = _max_age
    self.max_change_bps = _max_change_bps

    self.owner = _owner
    self.paused = False

    # Initialize last price snapshot to current feed price (best-effort)
    p: uint256 = self._read_price_1e18()
    self.last_price_1e18 = p
    self.last_update_time = block.timestamp

    log OwnershipTransferred(empty(address), _owner)
    log FeedUpdated(empty(address), _feed)
    log ParamsUpdated(_max_age, _max_change_bps)


@internal
def _only_owner():
    assert msg.sender == self.owner, "not owner"


@internal
@view
def _read_price_1e18() -> uint256:
    """
    Reads Chainlink latestRoundData, validates, returns 1e18 price.
    """
    rid: uint80 = 0
    ans: int256 = 0
    started: uint256 = 0
    updated: uint256 = 0
    air: uint80 = 0
    rid, ans, started, updated, air = staticcall AggregatorV3Interface(self.feed).latestRoundData()

    # Basic validity checks
    assert updated != 0, "no update"
    assert air >= rid, "stale round"
    assert ans > 0, "bad answer"

    # Staleness check (optional)
    if self.max_age != 0:
        assert block.timestamp - updated <= self.max_age, "stale price"

    # Normalize to 1e18
    # If feed has d decimals, then:
    # price_1e18 = answer * 10^(18 - d)  if d <= 18
    # price_1e18 = answer / 10^(d - 18)  if d > 18
    d: uint256 = self.feed_decimals
    a: uint256 = convert(ans, uint256)

    if d == 18:
        return a
    elif d < 18:
        return a * (10 ** (18 - d))
    else:
        return a // (10 ** (d - 18))


@internal
@view
def _within_circuit_breaker(new_price: uint256) -> bool:
    """
    Checks that new_price is within +/- max_change_bps of last_price_1e18.
    If max_change_bps == 0, always true.
    Note: last_price_1e18 only updates when owner calls snapshot_price().
    This is intentional for a minimal, explicit design.
    """
    if self.max_change_bps == 0:
        return True

    old: uint256 = self.last_price_1e18
    if old == 0:
        return True

    lower: uint256 = old * (BPS - self.max_change_bps) // BPS
    upper: uint256 = old * (BPS + self.max_change_bps) // BPS
    return new_price >= lower and new_price <= upper


# -------------------------
# Public API (aligned)
# -------------------------
@external
@view
def get_price() -> uint256:
    """
    Returns asset/USD price at 1e18.
    This matches VaultManager's expected Oracle interface.
    """
    assert not self.paused, "paused"

    p: uint256 = self._read_price_1e18()
    assert self._within_circuit_breaker(p), "circuit breaker"
    return p


# -------------------------
# Admin / Ops
# -------------------------
@external
def snapshot_price():
    """
    Updates last_price_1e18 for circuit breaker comparisons.
    In production, this could be automated by a keeper.
    For MVP, manual snapshot is enough to demonstrate the mechanism.
    """
    self._only_owner()
    p: uint256 = self._read_price_1e18()
    self.last_price_1e18 = p
    self.last_update_time = block.timestamp


@external
def set_paused(is_paused: bool):
    self._only_owner()
    self.paused = is_paused
    log Paused(is_paused)


@external
def set_params(_max_age: uint256, _max_change_bps: uint256):
    self._only_owner()
    assert _max_change_bps <= BPS, "bps too high"
    self.max_age = _max_age
    self.max_change_bps = _max_change_bps
    log ParamsUpdated(_max_age, _max_change_bps)


@external
def set_feed(new_feed: address):
    """
    Allows switching feeds (e.g., testnet vs mainnet).
    """
    self._only_owner()
    assert new_feed != empty(address), "feed=0"

    old: address = self.feed
    self.feed = new_feed
    self.feed_decimals = convert(staticcall AggregatorV3Interface(new_feed).decimals(), uint256)

    # Reset snapshot to current
    p: uint256 = self._read_price_1e18()
    self.last_price_1e18 = p
    self.last_update_time = block.timestamp

    log FeedUpdated(old, new_feed)


@external
def transfer_ownership(new_owner: address):
    self._only_owner()
    assert new_owner != empty(address), "owner=0"
    old: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old, new_owner)
