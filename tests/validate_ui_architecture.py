#!/usr/bin/env python3
"""Static guardrails for the professional Godot 4.7 UI/UX architecture."""
from pathlib import Path
root=Path(__file__).parents[1]
errors=[]
main=(root/'scripts/ui/main_ui.gd').read_text(encoding='utf-8')
map_code=(root/'scripts/ui/unified_map.gd').read_text(encoding='utf-8')
settings=(root/'scripts/core/settings_manager.gd').read_text(encoding='utf-8')
chart=(root/'scripts/ui/trend_chart.gd').read_text(encoding='utf-8')
palette=(root/'scripts/ui/command_palette.gd').read_text(encoding='utf-8')
toasts=(root/'scripts/ui/toast_stack.gd').read_text(encoding='utf-8')
touch_scroll=(root/'scripts/ui/touch_scroll_container.gd').read_text(encoding='utf-8')
for marker in ['CommandPaletteClass','ToastStackClass','_build_command_entries','_apply_responsive_layout','_refresh_map_context_panel','_apply_tooltip_preferences','HFlowContainer']:
    if marker not in main:errors.append(f'main professional UX marker missing: {marker}')
# Context selection must not rebuild the heavy map page.
context=main[main.index('func _refresh_unified_map_context'):main.index('func _on_map_municipal_action')]
if '_switch_tab' in context:errors.append('map context still rebuilds the entire map')
for marker in ['ui_density','colorblind_palette','tooltips_enabled','haptics_enabled']:
    if marker not in settings:errors.append(f'accessibility preference missing: {marker}')
for marker in ['_pan_velocity','func _process','colorblind_palette','tooltips_enabled','_touch_points','_handle_manual_pinch']:
    if marker not in map_code:errors.append(f'map UX marker missing: {marker}')
for marker in ['hovered_index','InputEventScreenTouch','KEY_LEFT','_draw_hover_card']:
    if marker not in chart:errors.append(f'interactive chart marker missing: {marker}')
if 'max_visible := 4' not in toasts or 'open_palette' not in palette:
    errors.append('toast stack or command palette incomplete')
for marker in ['InputEventScreenDrag','scroll_vertical','_velocity','drag_deadzone']:
    if marker not in touch_scroll:errors.append(f'touch scrolling marker missing: {marker}')
if 'pointing/emulate_mouse_from_touch=true' not in (root/'project.godot').read_text(encoding='utf-8'):
    errors.append('touch-to-mouse support is not explicit')
if '(24.0 if compact else 28.0)' not in main or 'const TEXT_SCALES = [1.0, 1.15, 1.30, 1.50]' not in settings:
    errors.append('readable mobile typography scale is not enforced')
if 'package/vibrate=true' not in (root/'export_presets.cfg').read_text(encoding='utf-8'):
    errors.append('Android haptic permission is not enabled')
if errors:raise SystemExit('UI ARCHITECTURE INVALID\n'+'\n'.join(errors))
print('UI ARCHITECTURE OK: readable typography, finger scrolling, manual two-finger pinch, persistent map and accessibility')
