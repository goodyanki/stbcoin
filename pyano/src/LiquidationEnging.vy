# @version 0.4.3
"""
LiquidationEngine.vy (MVP)
- Allows anyone to liquidate under-collateralized vaults
- Uses fixed-discount liquidation (no auction)
- Repays stablecoin debt and seizes collateral with penalty

Aligned with:
- VaultManager.vy
- StabilityEngine.vy
- Stablecoin.vy

MVP assumptions:
- Single collateral type
- Partial liquidation not supported (full liquidation only)
"""

from ethereum.ercs import IERC20


# -------------------------
# Events
# -------------------------
event Liquidated:
    user: indexed(address)
    liquidator: indexed(address)
    debt_repaid: uint256
    collateral_seized: uint256
    penalty_bps: uint256


# -------------------------
# Interfaces
# -------------------------
interface Stablecoin:
    def burn(from_: address, amount: uint256) -> bool: nonpayable

interface VaultManager:
    def get_vault(user: address) -> (uint256, uint256, bool): view
    def collateral_value_usd(user: address) -> uint256: view
    def collateral_ratio(user: address) -> uint256: view

    def decrease_debt(user: address, amount: uint256): nonpayable
    def withdraw_collateral(user: address, to: address, amount: uint256): nonpayable

interface StabilityEngine:
    def mcr() -> uint256: view


# -------------------------
# Storage
# -------------------------
stablecoin: public(address)
vault_manager: public(address)
engine: public(address)   # StabilityEngine

owner: public(address)

# Liquidation penalty (bps). Example: 500 = 5%
penalty_bps: public(uint256)

# Minimum CR at which liquidation is allowed (usually == engine.mcr)
liquidation_cr: public(uint256)


# -------------------------
# Constants
# -------------------------
BPS: constant(uint256) = 10_000
CR_PRECISION: constant(uint256) = 10**18


# -------------------------
# Constructor
# -------------------------
@deploy
def __init__(
    _stablecoin: address,
    _vault_manager: address,
    _engine: address,
    _owner: address,
    _penalty_bps: uint256
):
    assert _stablecoin != empty(address), "stablecoin=0"
    assert _vault_manager != empty(address), "vault=0"
    assert _engine != empty(address), "engine=0"
    assert _owner != empty(address), "owner=0"
    assert _penalty_bps <= 2_000, "penalty too high"  # <=20%

    self.stablecoin = _stablecoin
    self.vault_manager = _vault_manager
    self.engine = _engine
    self.owner = _owner

    self.penalty_bps = _penalty_bps
    self.liquidation_cr = staticcall StabilityEngine(_engine).mcr()


# -------------------------
# Internal
# -------------------------
@internal
@view
def _is_liquidatable(user: address) -> bool:
    cr: uint256 = staticcall VaultManager(self.vault_manager).collateral_ratio(user)
    return cr < self.liquidation_cr


# -------------------------
# Liquidation
# -------------------------
@external
def liquidate(user: address):
    """
    Full liquidation:
    - Liquidator repays entire debt in stablecoin
    - Receives collateral at a discount (penalty_bps)
    """
    assert self._is_liquidatable(user), "not liquidatable"

    coll: uint256 = 0
    debt: uint256 = 0
    exists: bool = False
    coll, debt, exists = staticcall VaultManager(self.vault_manager).get_vault(user)

    assert exists, "no vault"
    assert debt > 0, "no debt"
    assert coll > 0, "no collateral"

    # Liquidator must have approved stablecoin to this contract
    extcall IERC20(self.stablecoin).transferFrom(
        msg.sender,
        self,
        debt
    )

    # Burn repaid stablecoin
    ok: bool = extcall Stablecoin(self.stablecoin).burn(self, debt)
    assert ok, "burn failed"

    # Clear debt
    extcall VaultManager(self.vault_manager).decrease_debt(user, debt)

    # Calculate collateral to seize with penalty
    seize_amount: uint256 = coll * (BPS + self.penalty_bps) // BPS
    if seize_amount > coll:
        seize_amount = coll  # cap at full collateral

    # Withdraw collateral to liquidator
    extcall VaultManager(self.vault_manager).withdraw_collateral(user, msg.sender, seize_amount)

    log Liquidated(
        user,
        msg.sender,
        debt,
        seize_amount,
        self.penalty_bps
    )


# -------------------------
# Admin
# -------------------------
@external
def set_penalty_bps(new_bps: uint256):
    assert msg.sender == self.owner, "not owner"
    assert new_bps <= 2_000, "penalty too high"
    self.penalty_bps = new_bps


@external
def sync_liquidation_cr():
    """
    Sync liquidation threshold with engine.mcr()
    """
    self.liquidation_cr = staticcall StabilityEngine(self.engine).mcr()


@external
def transfer_ownership(new_owner: address):
    assert msg.sender == self.owner, "not owner"
    assert new_owner != empty(address), "owner=0"
    self.owner = new_owner
