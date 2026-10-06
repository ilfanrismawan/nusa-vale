with open('scripts/ui/ui_inventory.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace tooltip_hotbar block
old_snippet = '\tif slot_idx >= 0 and slot_idx < 8:\n\t\ttooltip_hotbar.text = "? HUD Slot #%d (Tekan \'%d\')" % [slot_idx + 1, slot_idx + 1]\n\t\ttooltip_hotbar.modulate = Color(0.4, 0.85, 0.4, 1.0)\n\t\ttooltip_hotbar.show()\n\telse:\n\t\ttooltip_hotbar.text = "Di Tas Penyimpanan"\n\t\ttooltip_hotbar.modulate = Color(0.7, 0.7, 0.7, 0.9)\n\t\ttooltip_hotbar.show()'

new_snippet = '\tvar is_in_hotbar = (GameState.hotbar_page * 8) <= slot_idx and slot_idx < ((GameState.hotbar_page + 1) * 8)\n\tif is_in_hotbar:\n\t\tvar hud_idx = (slot_idx % 8) + 1\n\t\ttooltip_hotbar.text = "HUD Slot #%d (Tekan \'%d\')" % [hud_idx, hud_idx]\n\t\ttooltip_hotbar.modulate = Color(0.4, 0.85, 0.4, 1.0)\n\t\ttooltip_hotbar.show()\n\telse:\n\t\ttooltip_hotbar.text = "Di Tas Penyimpanan"\n\t\ttooltip_hotbar.modulate = Color(0.7, 0.7, 0.7, 0.9)\n\t\ttooltip_hotbar.show()'

if old_snippet in content:
    content = content.replace(old_snippet, new_snippet, 1)
    print("Replaced tooltip_hotbar block OK")
else:
    print("NOT FOUND — trying hex search")
    # Find the line index
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'if slot_idx >= 0 and slot_idx < 8:' in line:
            print(f"Found at line {i+1}")
            # Replace 9 lines starting here
            lines[i] = '\tvar is_in_hotbar = (GameState.hotbar_page * 8) <= slot_idx and slot_idx < ((GameState.hotbar_page + 1) * 8)'
            lines[i+1] = '\tif is_in_hotbar:'
            lines[i+2] = '\t\tvar hud_idx = (slot_idx % 8) + 1'
            lines[i+3] = '\t\ttooltip_hotbar.text = "HUD Slot #%d (Tekan \'%d\')" % [hud_idx, hud_idx]'
            # i+4 (modulate) and i+5 (show) stay same
            content = '\n'.join(lines)
            print("Done line-based replace")
            break

# Replace badge_hotbar block
old_badge = '\tif slot_idx >= 0 and slot_idx < 8:\n\t\t\tbadge_hotbar.text = "HUD Slot #%d (Tombol %d)" % [slot_idx + 1, slot_idx + 1]\n\t\t\tbadge_hotbar.modulate = Color(0.25, 0.6, 0.25, 1.0)\n\t\telse:\n\t\t\tbadge_hotbar.text = "Di Tas Penyimpanan"\n\t\t\tbadge_hotbar.modulate = Color(0.55, 0.38, 0.2, 1.0)'

new_badge = '\tvar is_hotbar_slot = (GameState.hotbar_page * 8) <= slot_idx and slot_idx < ((GameState.hotbar_page + 1) * 8)\n\t\tif is_hotbar_slot:\n\t\t\tvar hud_slot_idx = (slot_idx % 8) + 1\n\t\t\tbadge_hotbar.text = "HUD Slot #%d (Tombol %d)" % [hud_slot_idx, hud_slot_idx]\n\t\t\tbadge_hotbar.modulate = Color(0.25, 0.6, 0.25, 1.0)\n\t\telse:\n\t\t\tbadge_hotbar.text = "Di Tas Penyimpanan"\n\t\t\tbadge_hotbar.modulate = Color(0.55, 0.38, 0.2, 1.0)'

if old_badge in content:
    content = content.replace(old_badge, new_badge, 1)
    print("Replaced badge_hotbar block OK")
else:
    print("badge_hotbar block NOT found exactly — trying line-based")
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'if slot_idx >= 0 and slot_idx < 8:' in line and 'badge_hotbar' in lines[i+1] if i+1 < len(lines) else False:
            print(f"Found badge block at line {i+1}")
            lines[i] = '\t\tif (GameState.hotbar_page * 8) <= slot_idx and slot_idx < ((GameState.hotbar_page + 1) * 8):'
            lines[i+1] = '\t\t\tvar hud_slot_idx = (slot_idx % 8) + 1'
            lines[i+2] = '\t\t\tbadge_hotbar.text = "HUD Slot #%d (Tombol %d)" % [hud_slot_idx, hud_slot_idx]'
            content = '\n'.join(lines)
            break

with open('scripts/ui/ui_inventory.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done writing")
