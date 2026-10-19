# Native player flow58 — not run

Stopped at the user's request to preserve the remaining limit and checkpoint the combined assembly. This agent launched no engine for this task, changed no production files and has no owned child to terminate. No production delta remains from services31_resume: the two home_approach58 files were integrated by root into stage58_07.

Target manifest supplied by root: `outputs/coordinator31_npc57/extended31/stage58_07/CANDIDATE58.json`, SHA256 `17f17cb0f4d9b577a68e02812c9272ec64e2cc7ec25eb0ade90e2b20a7eccaf9`,1212 pins. Use its actual `launch_arguments`, including `--city-player-shop=1`; recheck current stage before any continuation.

Required pending proof: real E interaction with the single cashier, buying through ordinary goods UI, actual Q equipment selection, right-button aim/cancel and right+left-button throw for grenade and Molotov. Use `Input.parse_input_event` through the viewport/input dispatch, never direct `_open_goods`, `_launch`, `select`, `purchase`, or direct calls to input handlers. Any initial player test placement must be recorded; movement through the actual exterior threshold and door must use normal player movement. NPCs must not be placed or moved by the fixture. Scheduler read lease and own-child watchdog required; preserve the user's ordinary57 game.

Read-only findings from current source:

- `player_shop_host.gd` ordinary E opens the talk panel only with a valid nearby cashier, on-foot authority, captured controls, and no weapon/cargo menu. E/Enter in talk opens goods. Goods keyboard controls are Tab for category, arrows for selection, Enter to buy, Esc to close. P shortcut is disabled in physical store mode.
- `preview_weapons.gd` receives Q through the player's unhandled input; Q opens/closes the equipment menu. Throwable buttons are added to `walk_weapon_ui.gd`'s scrollable grid. A real GUI button input is required; pressing its signal directly would miss the requested user flow.
- `player_throwables.gd` requires captured on-foot controls, empty jump, no modal, no weapon menu and equipped weapon `none`. A right event alone is insufficient: native physics also checks `Input.is_mouse_button_pressed(RIGHT)` during windup. Left press while right is held requests the throw; count is consumed by the real launch path after windup. Right release should cancel without spending.
- Existing `scripts/shop/tests/test_shop_city57.gd` is useful component evidence but calls `_open_goods`, selection, handler methods and `_launch` directly. Its PASS therefore does not establish this pending user flow. Existing player pose and city shop component receipts remain preserved.

No fixture was created or run. Headless native input is allowed by root if graphical focus interferes. Actual GUI dispatch, scroll visibility, cashier E versus door E, and player on-foot authority must be verified rather than assumed. Parent owns integration, F5 and Git.
