# rox_atm — ROX Store
Cash-machine UI for every ATM prop (Qbox + ox_target). Withdraw / deposit are validated on the server
(amount, balance, and the player must still be standing at the ATM).

1. `ensure rox_atm` after qbx_core, ox_lib, ox_target.
2. Turn off the ATM target of your old banking script (e.g. in Renewed-Banking / qb-banking config) so only this one shows.
3. Other scripts can open it: `exports.rox_atm:OpenATM(entity)`.
