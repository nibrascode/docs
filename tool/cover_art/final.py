import json, subprocess, sys
# id, material, colour, vein, style, finish, tone, cell, seed, ink(light/dark)
F = [
 ("emerald_leather_star", "leather", "#1f4a3a", "border8", "gild", "gold", 120),
 ("navy_leather_shamsa", "leather", "#16264a", "shamsa", "gild", "gold", 0),
 ("burgundy_leather_corners", "leather", "#5a1a22", "corners", "gild", "gold", 0),
 ("onyx_leather_hex", "leather", "#17171a", "border6", "gild", "gold", 140),
 ("ivory_linen_corners", "linen", "#ebe2cd", "corners", "gild", "bronze", 0),
 ("sand_linen_star_emboss", "linen", "#d9c7a3", "field8", "emboss", None, 130),
 ("teal_suede_shamsa", "suede", "#164a4f", "shamsa", "gild", "gold", 0),
 ("plum_leather_hex_emboss", "leather", "#3d1f3f", "field6", "emboss", None, 170),
 ("pearl_silk_corners", "silk", "#ece4d4", "corners", "gild", "gold", 0),
 ("forest_leather_headfoot", "leather", "#1c3324", "headfoot", "gild", "gold", 120),
 ("noir_suede_headfoot", "suede", "#141416", "headfoot", "gild", "gold", 120),
 ("cocoa_leather_star_emboss", "leather", "#4a2e1c", "field8", "emboss", None, 140),
 ("midnight_suede_hex", "suede", "#0f1a33", "border6", "gild", "silver", 140),
 ("terracotta_linen_star", "linen", "#9a4b34", "border8", "gild", "gold", 120),
 ("olive_leather_shamsa", "leather", "#3a4220", "shamsa", "gild", "gold", 0),
 ("charcoal_linen_star", "linen", "#2b2d31", "border8", "gild", "rose", 120),
 ("cream_leather_hex_emboss", "leather", "#d8cbb0", "field6", "emboss", None, 170),
 ("sapphire_leather_corners", "leather", "#123a6b", "corners", "gild", "silver", 0),
 ("rose_silk_star", "silk", "#e7d3cc", "border8", "gild", "rose", 120),
 ("wine_suede_hex", "suede", "#4a1520", "border6", "gild", "gold", 140),
 ("slate_silk_shamsa", "silk", "#3a4049", "shamsa", "gild", "silver", 0),
 ("saffron_linen_star_emboss", "linen", "#d6a650", "field8", "emboss", None, 130),
 ("ink_leather_headfoot", "leather", "#101826", "headfoot", "gild", "gold", 120),
 ("jade_silk_hex", "silk", "#2f5d50", "border6", "gild", "gold", 140),
 ("copper_leather_shamsa", "leather", "#5b3020", "shamsa", "gild", "bronze", 0),
 ("ivory_linen_shamsa", "linen", "#efe9dd", "shamsa", "gild", "gold", 0),
 ("indigo_linen_hex_emboss", "linen", "#23305a", "field6", "emboss", None, 170),
 ("black_silk_star", "silk", "#121214", "border8", "gild", "gold", 110),
 ("maroon_silk_corners", "silk", "#3f1418", "corners", "gild", "gold", 0),
 ("moss_linen_headfoot", "linen", "#4c5a36", "headfoot", "gild", "gold", 120),
 ("royal_suede_shamsa", "suede", "#2a1d5c", "shamsa", "gild", "gold", 0),
 ("ash_linen_star_emboss", "linen", "#cfcbc4", "field8", "emboss", None, 130),
 ("tobacco_leather_hex", "leather", "#3b2618", "border6", "gild", "gold", 140),
 ("aqua_linen_corners", "linen", "#2f6b6b", "corners", "gild", "silver", 0),
 ("garnet_leather_headfoot", "leather", "#4c0f1a", "headfoot", "gild", "gold", 120),
 ("obsidian_silk_shamsa", "silk", "#0e0f12", "shamsa", "gild", "gold", 0),
 ("desert_suede_star_emboss", "suede", "#c9a77a", "field8", "emboss", None, 130),
 ("petrol_leather_star", "leather", "#123b40", "border8", "gild", "gold", 110),
 ("ivory_silk_hex", "silk", "#f1ece2", "border6", "gild", "gold", 140),
 ("aubergine_linen_shamsa", "linen", "#3a1f36", "shamsa", "gild", "rose", 0),
 ("steel_suede_corners", "suede", "#2c3540", "corners", "gild", "silver", 0),
 ("honey_leather_headfoot", "leather", "#7a5222", "headfoot", "gild", "gold", 120),
 ("noir_linen_hex", "linen", "#1a1a1d", "border6", "gild", "gold", 140),
 ("emerald_silk_corners", "silk", "#1d4537", "corners", "gild", "gold", 0),
 ("navy_linen_star_emboss", "linen", "#1d2b4d", "field8", "emboss", None, 130),
 ("bordeaux_suede_star", "suede", "#4b1424", "border8", "gild", "gold", 120),
]
if __name__ == '__main__':
    idx = [int(a) for a in sys.argv[1:]] or range(len(F))
    args = []
    for i in idx:
        rid, mat, col, style, fin, tone, cell = F[i]
        args.append(json.dumps([rid, mat, col, None, style, fin, tone, cell, 1000 + i * 37]))
    subprocess.run(["python3", "recipes2.py"] + args, check=True)
