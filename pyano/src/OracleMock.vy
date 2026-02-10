# @version 0.4.3
"""
OracleMock.vy
- Returns collateral price in USD with 1e18 precision
- Has staleness check (max_age)
- Has circuit breaker (max_change_bps) + manual pause
- Owner can update price (for local testing / MVP)

This aligns with VaultManager.vy interface:
interface Oracle:
    def get_price() -> uint256: view   # collateral price in USD, 1e18

Notes:
- For MVP, stablecoin FXD is treated as $1 (1e18) by design.
  You do NOT need an oracle for FXD unless you're implementing peg-aware adjustments.
"""

event PriceUpdated:
    old_price: uint256
    new_price: uint256
    publish_time: uint256

event MaxAgeUpdated:
    old_max_age: uint256
    new_max_age: uint256

event MaxChangeUpdated:
    old_bps: uint256
    new_bps: uint256

event Paused:
    is_paused: bool

event OwnershipTransferred:
    old_owner: address
    new_owner: address


owner: public(address)

# Price in USD, 1e18 precision (e.g. $2000 => 2000e18)
price: public(uint256)
last_updated: public(uint256)

# Staleness threshold in seconds (e.g. 3600)
max_age: public(uint256)

# Circuit breaker: max allowed change per update in basis points (e.g. 2000 = 20%)
max_change_bps: public(uint256)

paused: public(bool)

BPS: constant(uint256) = 10_000
PRICE_PRECISION: constant(uint256) = 10**18


@deploy
def __init__(_owner: address, _initial_price: uint256, _max_age: uint256, _max_change_bps: uint256):
    assert _owner != empty(address), "owner=0"
    assert _initial_price > 0, "price=0"
    assert _max_change_bps <= BPS, "max_change too high"

    self.owner = _owner
    self.price = _initial_price
    self.last_updated = block.timestamp
    self.max_age = _max_age
    self.max_change_bps = _max_change_bps
    self.paused = False

    log OwnershipTransferred(empty(address), _owner)
    log PriceUpdated(0, _initial_price, block.timestamp)


@internal
def _only_owner():
    assert msg.sender == self.owner, "not owner"


@external
@view
def get_price() -> uint256:
    assert not self.paused, "paused"
    assert self.price > 0, "price=0"
    if self.max_age != 0:
        assert block.timestamp - self.last_updated <= self.max_age, "stale price"
    return self.price


@external
def set_price(new_price: uint256):
    """
    Owner sets a new price (1e18).
    Circuit breaker limits jump size unless max_change_bps == 0 (disabled).
    """
    self._only_owner()
    assert not self.paused, "paused"
    assert new_price > 0, "price=0"

    old: uint256 = self.price

    if self.max_change_bps != 0:
        # allowed range: old * (1 - bps) .. old * (1 + bps)
        lower: uint256 = old * (BPS - self.max_change_bps) // BPS
        upper: uint256 = old * (BPS + self.max_change_bps) // BPS
        assert new_price >= lower and new_price <= upper, "circuit breaker"

    self.price = new_price
    self.last_updated = block.timestamp

    log PriceUpdated(old, new_price, block.timestamp)


@external
def set_max_age(new_max_age: uint256):
    self._only_owner()
    old: uint256 = self.max_age
    self.max_age = new_max_age
    log MaxAgeUpdated(old, new_max_age)


@external
def set_max_change_bps(new_bps: uint256):
    """
    Set to 0 to disable circuit breaker.
    """
    self._only_owner()
    assert new_bps <= BPS, "bps too high"
    old: uint256 = self.max_change_bps
    self.max_change_bps = new_bps
    log MaxChangeUpdated(old, new_bps)


@external
def set_paused(is_paused: bool):
    self._only_owner()
    self.paused = is_paused
    log Paused(is_paused)


@external
def transfer_ownership(new_owner: address):
    self._only_owner()
    assert new_owner != empty(address), "owner=0"
    old: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old, new_owner)


# Optional helper for UI / docs: stablecoin is assumed to be ~$1
@external
@view
def get_stablecoin_usd() -> uint256:
    """
    Returns 1e18 (=$1). This is a convention for MVP.
    """
    return PRICE_PRECISION
