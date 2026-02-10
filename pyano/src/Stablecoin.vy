# @version 0.4.3
"""
Stablecoin.vy (FXD / your stablecoin)
- Minimal ERC20
- Mint/Burn restricted to a designated minter (your StabilityEngine / MinterRedeemer)
- Owner can rotate minter (for upgrade of engine during development)

MVP notes:
- No permit (EIP-2612) yet
- No blacklist / pause yet (add later if you want a circuit-breaker at token level)
"""

from ethereum.ercs import IERC20


event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

event MinterUpdated:
    old_minter: address
    new_minter: address

event OwnershipTransferred:
    old_owner: address
    new_owner: address


name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)

_total_supply: uint256
_balances: HashMap[address, uint256]
_allowances: HashMap[address, HashMap[address, uint256]]

owner: public(address)
minter: public(address)


@deploy
def __init__(
    _name: String[64],
    _symbol: String[32],
    _decimals: uint256,
    _owner: address,
    _minter: address
):
    assert _owner != empty(address), "owner=0"
    assert _minter != empty(address), "minter=0"

    self.name = _name
    self.symbol = _symbol
    self.decimals = _decimals

    self.owner = _owner
    self.minter = _minter

    log OwnershipTransferred(empty(address), _owner)
    log MinterUpdated(empty(address), _minter)


# -----------------------------
# ERC20 view functions
# -----------------------------
@external
@view
def totalSupply() -> uint256:
    return self._total_supply


@external
@view
def balanceOf(account: address) -> uint256:
    return self._balances[account]


@external
@view
def allowance(owner: address, spender: address) -> uint256:
    return self._allowances[owner][spender]


# -----------------------------
# ERC20 core
# -----------------------------
@internal
def _transfer(_from: address, _to: address, _amount: uint256):
    assert _to != empty(address), "to=0"
    assert _from != empty(address), "from=0"
    assert _amount != 0, "amount=0"

    self._balances[_from] -= _amount
    self._balances[_to] += _amount

    log Transfer(_from, _to, _amount)


@external
def transfer(to: address, amount: uint256) -> bool:
    self._transfer(msg.sender, to, amount)
    return True


@external
def approve(spender: address, amount: uint256) -> bool:
    assert spender != empty(address), "spender=0"
    self._allowances[msg.sender][spender] = amount
    log Approval(msg.sender, spender, amount)
    return True


@external
def transferFrom(_from: address, _to: address, _amount: uint256) -> bool:
    assert _amount != 0, "amount=0"

    allowed: uint256 = self._allowances[_from][msg.sender]
    assert allowed >= _amount, "insufficient allowance"

    self._allowances[_from][msg.sender] = allowed - _amount
    log Approval(_from, msg.sender, self._allowances[_from][msg.sender])

    self._transfer(_from, _to, _amount)
    return True


# -----------------------------
# Mint / Burn (restricted)
# -----------------------------
@internal
def _mint(_to: address, _amount: uint256):
    assert _to != empty(address), "to=0"
    assert _amount != 0, "amount=0"

    self._total_supply += _amount
    self._balances[_to] += _amount

    log Transfer(empty(address), _to, _amount)


@internal
def _burn(_from: address, _amount: uint256):
    assert _from != empty(address), "from=0"
    assert _amount != 0, "amount=0"

    self._balances[_from] -= _amount
    self._total_supply -= _amount

    log Transfer(_from, empty(address), _amount)


@external
def mint(to: address, amount: uint256) -> bool:
    assert msg.sender == self.minter, "not minter"
    self._mint(to, amount)
    return True


@external
def burn(from_: address, amount: uint256) -> bool:
    assert msg.sender == self.minter, "not minter"
    self._burn(from_, amount)
    return True


# -----------------------------
# Admin
# -----------------------------
@external
def transfer_ownership(new_owner: address):
    assert msg.sender == self.owner, "not owner"
    assert new_owner != empty(address), "new_owner=0"

    old: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old, new_owner)


@external
def set_minter(new_minter: address):
    assert msg.sender == self.owner, "not owner"
    assert new_minter != empty(address), "minter=0"

    old: address = self.minter
    self.minter = new_minter
    log MinterUpdated(old, new_minter)
