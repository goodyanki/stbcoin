# @version 0.4.3
"""
StabilityEngine.vy (Hybrid / Maker-style MVP)
- Orchestrates: VaultManager <-> Stablecoin
- Lets users mint FXD against collateral (over-collateralized)
- Lets users repay/burn FXD to reduce debt
- Enforces minimum collateral ratio (MCR)
- Charges simple mint / repay fees (bps)
- Provides a safe withdrawal path (only if still healthy after)

Alignment notes (with your previous files):
- Uses Stablecoin.vy's mint() and burn() (minter-only)
- Uses VaultManager.vy's increase_debt(), decrease_debt(), withdraw_collateral()
- Collateral valuation + CR computation comes from VaultManager (oracle lives there)

MVP simplifications:
- No interest accrual over time (no per-second stability fee) — fees are per action
- Single collateral type is handled by VaultManager
- Liquidation is handled in a separate LiquidationEngine later
"""

from ethereum.ercs import IERC20


# -------------------------
# Events
# -------------------------
event Minted:
    user: indexed(address)
    amount_out: uint256
    fee_paid: uint256
    new_debt: uint256

event Repaid:
    user: indexed(address)
    amount_in: uint256
    fee_paid: uint256
    new_debt: uint256

event CollateralWithdrawnViaEngine:
    user: indexed(address)
    amount: uint256
    new_cr: uint256

event ParamsUpdated:
    mcr: uint256
    mint_fee_bps: uint256
    repay_fee_bps: uint256
    debt_cap_per_vault: uint256
    global_debt_cap: uint256


# -------------------------
# Interfaces
# -------------------------
interface Stablecoin:
    def mint(to: address, amount: uint256) -> bool: nonpayable
    def burn(from_: address, amount: uint256) -> bool: nonpayable

interface VaultManager:
    def open_vault(): nonpayable
    def get_vault(user: address) -> (uint256, uint256, bool): view
    def collateral_value_usd(user: address) -> uint256: view
    def collateral_ratio(user: address) -> uint256: view

    def increase_debt(user: address, amount: uint256): nonpayable
    def decrease_debt(user: address, amount: uint256): nonpayable
    def withdraw_collateral(user: address, to: address, amount: uint256): nonpayable


# -------------------------
# Storage
# -------------------------
stablecoin: public(address)
vault_manager: public(address)

owner: public(address)

# Minimum collateral ratio (1e18 precision). Example: 150% = 1.5e18
mcr: public(uint256)

# Simple action fees (basis points). 100 bps = 1%
mint_fee_bps: public(uint256)
repay_fee_bps: public(uint256)

# Caps (optional but good for safety / demo)
debt_cap_per_vault: public(uint256)   # max debt per user vault
global_debt_cap: public(uint256)      # max total system debt
total_system_debt: public(uint256)    # tracked by engine


# -------------------------
# Constants
# -------------------------
CR_PRECISION: constant(uint256) = 10**18
BPS: constant(uint256) = 10_000


# -------------------------
# Constructor
# -------------------------
@deploy
def __init__(
    _stablecoin: address,
    _vault_manager: address,
    _owner: address,
    _mcr: uint256,
    _mint_fee_bps: uint256,
    _repay_fee_bps: uint256,
    _debt_cap_per_vault: uint256,
    _global_debt_cap: uint256
):
    assert _stablecoin != empty(address), "stablecoin=0"
    assert _vault_manager != empty(address), "vault=0"
    assert _owner != empty(address), "owner=0"
    assert _mcr >= CR_PRECISION, "mcr<1"
    assert _mint_fee_bps <= 2_000, "mint fee too high"      # guardrail: <=20%
    assert _repay_fee_bps <= 2_000, "repay fee too high"

    self.stablecoin = _stablecoin
    self.vault_manager = _vault_manager
    self.owner = _owner

    self.mcr = _mcr
    self.mint_fee_bps = _mint_fee_bps
    self.repay_fee_bps = _repay_fee_bps

    self.debt_cap_per_vault = _debt_cap_per_vault
    self.global_debt_cap = _global_debt_cap

    log ParamsUpdated(_mcr, _mint_fee_bps, _repay_fee_bps, _debt_cap_per_vault, _global_debt_cap)


# -------------------------
# Internal helpers
# -------------------------
@internal
@view
def _vault_debt(user: address) -> uint256:
    _coll: uint256 = 0
    _debt: uint256 = 0
    _exists: bool = False
    _coll, _debt, _exists = staticcall VaultManager(self.vault_manager).get_vault(user)
    assert _exists, "no vault"
    return _debt


@internal
@view
def _is_healthy(user: address) -> bool:
    cr: uint256 = staticcall VaultManager(self.vault_manager).collateral_ratio(user)
    # If debt == 0, VaultManager returns a very large number => healthy
    return cr >= self.mcr


@internal
@view
def _max_debt_allowed_by_collateral(user: address) -> uint256:
    """
    maxDebt = collateralValueUSD / MCR
    all in 1e18 precision
    """
    value_usd: uint256 = staticcall VaultManager(self.vault_manager).collateral_value_usd(user)
    if value_usd == 0:
        return 0
    return value_usd * CR_PRECISION // self.mcr


@internal
@view
def _charge_bps(amount: uint256, fee_bps: uint256) -> uint256:
    if fee_bps == 0:
        return 0
    return amount * fee_bps // BPS


@internal
@view
def _enforce_caps(user: address, new_user_debt: uint256, delta_debt: uint256):
    if self.debt_cap_per_vault != 0:
        assert new_user_debt <= self.debt_cap_per_vault, "vault debt cap"
    if self.global_debt_cap != 0:
        assert self.total_system_debt + delta_debt <= self.global_debt_cap, "global debt cap"


# -------------------------
# User actions
# -------------------------
@external
def open_vault_if_needed():
    """
    Convenience wrapper: tries to open a vault.
    If vault already exists, it will revert in VaultManager.
    For MVP you can just call VaultManager.open_vault directly.
    """
    extcall VaultManager(self.vault_manager).open_vault()


@external
def mint(amount_out: uint256):
    """
    Mint stablecoin against your vault (over-collateralized).
    - amount_out: FXD amount user wants to receive (1e18)
    Fees:
    - Mint fee is added on top of debt (debt increases by amount_out + fee)
    """
    assert amount_out > 0, "amount=0"

    current_debt: uint256 = self._vault_debt(msg.sender)

    fee: uint256 = self._charge_bps(amount_out, self.mint_fee_bps)
    debt_increase: uint256 = amount_out + fee
    new_debt: uint256 = current_debt + debt_increase

    # Collateral constraint
    max_debt: uint256 = self._max_debt_allowed_by_collateral(msg.sender)
    assert new_debt <= max_debt, "insufficient collateral"

    # Caps
    self._enforce_caps(msg.sender, new_debt, debt_increase)

    # Update debt first (state change), then mint
    extcall VaultManager(self.vault_manager).increase_debt(msg.sender, debt_increase)
    self.total_system_debt += debt_increase

    ok: bool = extcall Stablecoin(self.stablecoin).mint(msg.sender, amount_out)
    assert ok, "mint failed"

    log Minted(msg.sender, amount_out, fee, new_debt)


@external
def repay(amount_in: uint256):
    """
    Repay debt by burning FXD.
    Implementation choice (safer):
    - User transfers FXD to engine via transferFrom (needs approve)
    - Engine burns its own balance
    Debt reduction:
    - repay fee is taken from the amount_in; only net reduces debt
      net = amount_in - fee
    """
    assert amount_in > 0, "amount=0"

    current_debt: uint256 = self._vault_debt(msg.sender)
    assert current_debt > 0, "no debt"

    fee: uint256 = self._charge_bps(amount_in, self.repay_fee_bps)
    assert amount_in > fee, "fee too large"

    net: uint256 = amount_in - fee
    if net > current_debt:
        net = current_debt
        # amount burned should match net + fee? For simplicity, burn full amount_in
        # and only reduce debt by net. Excess would be "donation".
        # To avoid confusion, we enforce amount_in <= current_debt + fee.
        assert amount_in <= current_debt + fee, "repay too much"

    # Pull FXD from user
    extcall IERC20(self.stablecoin).transferFrom(msg.sender, self, amount_in)

    # Burn FXD held by engine
    ok_burn: bool = extcall Stablecoin(self.stablecoin).burn(self, amount_in)
    assert ok_burn, "burn failed"

    # Decrease debt by net
    extcall VaultManager(self.vault_manager).decrease_debt(msg.sender, net)
    self.total_system_debt -= net

    new_debt: uint256 = current_debt - net
    log Repaid(msg.sender, amount_in, fee, new_debt)


@external
def withdraw_collateral(amount: uint256):
    """
    Safe collateral withdrawal via engine:
    - Tentatively withdraw in VaultManager (it will update and transfer)
    - Then ensure position still meets MCR
    IMPORTANT: If the post-check fails, we revert and the whole tx reverts,
               so the collateral transfer is rolled back.
    """
    assert amount > 0, "amount=0"

    # Will revert if no vault or insufficient collateral
    extcall VaultManager(self.vault_manager).withdraw_collateral(msg.sender, msg.sender, amount)

    assert self._is_healthy(msg.sender), "would breach mcr"

    new_cr: uint256 = staticcall VaultManager(self.vault_manager).collateral_ratio(msg.sender)
    log CollateralWithdrawnViaEngine(msg.sender, amount, new_cr)


# -------------------------
# Admin
# -------------------------
@external
def set_params(
    _mcr: uint256,
    _mint_fee_bps: uint256,
    _repay_fee_bps: uint256,
    _debt_cap_per_vault: uint256,
    _global_debt_cap: uint256
):
    assert msg.sender == self.owner, "not owner"
    assert _mcr >= CR_PRECISION, "mcr<1"
    assert _mint_fee_bps <= 2_000, "mint fee too high"
    assert _repay_fee_bps <= 2_000, "repay fee too high"

    self.mcr = _mcr
    self.mint_fee_bps = _mint_fee_bps
    self.repay_fee_bps = _repay_fee_bps
    self.debt_cap_per_vault = _debt_cap_per_vault
    self.global_debt_cap = _global_debt_cap

    log ParamsUpdated(_mcr, _mint_fee_bps, _repay_fee_bps, _debt_cap_per_vault, _global_debt_cap)


@external
def transfer_ownership(new_owner: address):
    assert msg.sender == self.owner, "not owner"
    assert new_owner != empty(address), "owner=0"
    self.owner = new_owner
