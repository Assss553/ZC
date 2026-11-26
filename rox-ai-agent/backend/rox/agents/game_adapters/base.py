"""Game adapters: each declares which window it targets, which inputs are allowed and game-specific hints.
Only single-player games / modes that permit automation. No memory reading, injection or anti-cheat bypass:
adapters see only screenshots and send OS-level input, like a human."""
from dataclasses import dataclass, field


@dataclass
class GameAdapter:
    id: str
    name: str
    window_hint: str                     # substring of window title
    description: str
    hints: str = ""
    allowed_keys: set[str] | None = None  # None = any key; type() is blocked when a whitelist exists
    allow_typing: bool = True
    turn_delay: float = 0.0
    tags: list[str] = field(default_factory=list)

    def key_filter(self, text: str) -> bool:
        if self.allowed_keys is None:
            return True
        parts = [p.strip().lower() for p in text.replace("+", " ").split() if p.strip()]
        return bool(parts) and all(p in self.allowed_keys for p in parts)


ADAPTERS: dict[str, GameAdapter] = {}


def register(a: GameAdapter) -> GameAdapter:
    ADAPTERS[a.id] = a
    return a


register(GameAdapter(
    id="generic", name="Generic single-player (vision)", window_hint="",
    description="Any single-player game window. Claude reads the screen and plays with mouse/keyboard. Quality depends on the game; fast reflex games are not suitable.",
    hints="Explore menus carefully. Take a screenshot after every few actions to verify the effect.", tags=["experimental"]))

register(GameAdapter(
    id="game2048", name="2048 (browser / desktop)", window_hint="2048",
    description="Tile puzzle. Only arrow keys allowed.",
    hints="Strategy: keep the largest tile in a corner (bottom-left). Prefer Down and Left, use Right when needed, Up only as last resort. After each move take a screenshot and read the board.",
    allowed_keys={"up", "down", "left", "right"}, allow_typing=False, tags=["puzzle", "turn-based"]))

register(GameAdapter(
    id="solitaire", name="Microsoft Solitaire Collection (Klondike)", window_hint="Solitaire",
    description="Turn-based card game, mouse only.",
    hints="Use drag (left_click_drag) to move cards; click the stock to draw. Never click ads or purchase buttons.",
    allowed_keys={"escape"}, allow_typing=False, tags=["cards", "turn-based"]))

register(GameAdapter(
    id="minesweeper", name="Minesweeper", window_hint="Minesweeper",
    description="Logic puzzle, mouse only.",
    hints="Left click to reveal, right click to flag. Deduce from numbers; only guess when no safe move exists.",
    allowed_keys=set(), allow_typing=False, tags=["puzzle"]))
