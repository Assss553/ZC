# rox_bank — ROX Store
Bank branches for Qbox (ox_target + ox_lib + oxmysql). `ensure rox_bank` after qbx_core and ox_target.
- 8 branches with blips (`Config.Banks`), open with the target "Open bank".
- Deposit, withdraw, transfer (by phone number, account number, citizen ID or server ID; receiver must be online), statistics for the last 7 days.
- Every action is checked on the server (amount, balance, player standing at a branch). History in `rox_bank_tx` (created automatically).
- 3D panel tilts toward the mouse. Other scripts: `exports.rox_bank:OpenBank('Branch name')`.
