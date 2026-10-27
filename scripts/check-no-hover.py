"""Guard the interaction contract that previously regressed in preview 1.5."""
from pathlib import Path
banned = ('HoverState', 'onHover', 'NSTrackingArea', 'mouseEntered(', 'mouseExited(', 'mouseMoved(')
for file in Path('Sources').rglob('*.swift'):
    for pattern in banned:
        assert pattern not in file.read_text(), f'{file}: forbidden hover behavior: {pattern}'
print('Passed no-hover source regression guard (all app sources).')
