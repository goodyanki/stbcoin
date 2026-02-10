# @version 0.4.3
"""
VaultManager.vy
- Manages CDPs / Vaults
- Tracks collateral and debt
- Calculates collateral ratio (CR)
- Single-collateral MVP (native ETH)

Design notes (MVP):
- One vault per user (simplifies logic)
- Single collateral type
- No liquidation logic here (delegated to LiquidationEngine)
"""


# -------------------------
# Events
# -------------------------
event VaultOpened:
    owner: indexed(address)

event CollateralDeposited:
    owner: indexed(address)
    amount: uint256

event CollateralWithdrawn:
    owner: indexed(address)
    amount: uint256

event DebtIncreased:
    owner: indexed(address)
    amount: uint256

event DebtRepaid:
    owner: indexed(address)
    amount: uint256


# -------------------------
# Structs
# -------------------------
struct Vault:
    collateral: uint256
    debt: uint256
    exists: bool


# -------------------------
# Storage
# -------------------------
vaults: HashMap[address, Vault]

engine: public(address)               # StabilityEngine (authorized)
liquidation_engine: public(address)   # LiquidationEngine (authorized)
oracle: public(address)               # price oracle (ETH/USD)

owner: public(address)


# -------------------------
# Constants
# -------------------------
PRICE_PRECISION: constant(uint256) = 10**18
CR_PRECISION: constant(uint256) = 10**18


# -------------------------
# Interfaces
# -------------------------
interface Oracle:
    def get_price() -> uint256: view   # collateral price in USD, 1e18


# -------------------------
# Constructor
# -------------------------
@deploy
def __init__(
    _oracle: address,
    _engine: address,
    _owner: address
):
    assert _oracle != empty(address), "oracle=0"
    assert _engine != empty(address), "engine=0"
    assert _owner != empty(address), "owner=0"

    self.oracle = _oracle
    self.engine = _engine
    self.owner = _owner


# -------------------------
# Modifiers (manual)
# -------------------------
@internal
def _only_authorized_operator():
    assert msg.sender == self.engine or msg.sender == self.liquidation_engine, "not authorized"


@internal
def _only_owner():
    assert msg.sender == self.owner, "not owner"


# -------------------------
# Vault lifecycle
# -------------------------
@external
def open_vault():
    v: Vault = self.vaults[msg.sender]
    assert not v.exists, "vault exists"

    self.vaults[msg.sender] = Vault({
        collateral: 0,
        debt: 0,
        exists: True
    })

    log VaultOpened(msg.sender)


# -------------------------
# Collateral management (native ETH)
# -------------------------
@external
@payable
def deposit_collateral():
    v: Vault = self.vaults[msg.sender]
    assert v.exists, "no vault"

    amount: uint256 = msg.value
    assert amount > 0, "amount=0"

    v.collateral += amount
    self.vaults[msg.sender] = v

    log CollateralDeposited(msg.sender, amount)


@external
def withdraw_collateral(user: address, to: address, amount: uint256):
    self._only_authorized_operator()
    assert user != empty(address), "user=0"
    assert to != empty(address), "to=0"
    assert amount > 0, "amount=0"

    v: Vault = self.vaults[user]
    assert v.exists, "no vault"
    assert v.collateral >= amount, "insufficient collateral"

    v.collateral -= amount
    self.vaults[user] = v

    send(to, amount)

    log CollateralWithdrawn(user, amount)


# -------------------------
# Debt management (engine-only)
# -------------------------
@external
def increase_debt(user: address, amount: uint256):
    assert msg.sender == self.engine, "not engine"
    assert amount > 0, "amount=0"

    v: Vault = self.vaults[user]
    assert v.exists, "no vault"

    v.debt += amount
    self.vaults[user] = v

    log DebtIncreased(user, amount)


@external
def decrease_debt(user: address, amount: uint256):
    assert msg.sender == self.engine or msg.sender == self.liquidation_engine, "not authorized"
    assert amount > 0, "amount=0"

    v: Vault = self.vaults[user]
    assert v.exists, "no vault"
    assert v.debt >= amount, "repay too much"

    v.debt -= amount
    self.vaults[user] = v

    log DebtRepaid(user, amount)


# -------------------------
# Views
# -------------------------
@external
@view
def get_vault(user: address) -> Vault:
    return self.vaults[user]


@external
@view
def collateral_value_usd(user: address) -> uint256:
    v: Vault = self.vaults[user]
    if not v.exists:
        return 0

    price: uint256 = staticcall Oracle(self.oracle).get_price()
    return v.collateral * price // PRICE_PRECISION


@external
@view
def collateral_ratio(user: address) -> uint256:
    v: Vault = self.vaults[user]
    if not v.exists or v.debt == 0:
        return max_value(uint256)  # infinite CR

    price: uint256 = staticcall Oracle(self.oracle).get_price()
    value_usd: uint256 = v.collateral * price // PRICE_PRECISION
    return value_usd * CR_PRECISION // v.debt


# -------------------------
# Admin
# -------------------------
@external
def set_engine(new_engine: address):
    self._only_owner()
    assert new_engine != empty(address), "engine=0"
    self.engine = new_engine


@external
def set_liquidation_engine(new_liquidation_engine: address):
    self._only_owner()
    assert new_liquidation_engine != empty(address), "liquidation=0"
    self.liquidation_engine = new_liquidation_engine


@external
def set_oracle(new_oracle: address):
    self._only_owner()
    assert new_oracle != empty(address), "oracle=0"
    self.oracle = new_oracle
