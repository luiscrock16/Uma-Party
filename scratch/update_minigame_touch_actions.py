import os

project_dir = r"e:/PROYECTOS GODOT/Umamusume party/uma-party/scripts"

minigame_actions = {
    "minijuego_plataformas.gd": ("modo_actual = Modo.FFA", 'modo_actual = Modo.FFA\n\tGlobal.establecer_texto_accion_tactil("EMPUJAR")'),
    "minijuego_explosion.gd": ("modo_actual = Modo.FFA", 'modo_actual = Modo.FFA\n\tGlobal.establecer_texto_accion_tactil("SPRINT")'),
    "minijuego_garra.gd": ("modo_actual = Modo.JEFE_1V3", 'modo_actual = Modo.JEFE_1V3\n\tGlobal.establecer_texto_accion_tactil("ATRAPAR")'),
    "minijuego_canones.gd": ("modo_actual = Modo.FFA", 'modo_actual = Modo.FFA\n\tGlobal.establecer_texto_accion_tactil("DISPARAR")'),
    "minijuego_pista.gd": ("modo_actual = Modo.EQUIPOS_2V2", 'modo_actual = Modo.EQUIPOS_2V2\n\tGlobal.establecer_texto_accion_tactil("ACELERAR")'),
    "minijuego_templo.gd": ("modo_actual = Modo.FFA", 'modo_actual = Modo.FFA\n\tGlobal.establecer_texto_accion_tactil("IMPULSO")'),
    "minijuego_globos.gd": ("modo_actual = Modo.EQUIPOS_2V2", 'modo_actual = Modo.EQUIPOS_2V2\n\tGlobal.establecer_texto_accion_tactil("EMPUJAR")'),
    "minijuego_janken.gd": ("modo_actual = Modo.EQUIPOS_2V2", 'modo_actual = Modo.EQUIPOS_2V2\n\tGlobal.establecer_texto_accion_tactil("ELEGIR")'),
    "minijuego_trivia.gd": ("modo_actual = Modo.FFA", 'modo_actual = Modo.FFA\n\tGlobal.establecer_texto_accion_tactil("SALTO")'),
    "minijuego_atrapa_colas.gd": ("modo_actual = Modo.JEFE_1V3", 'modo_actual = Modo.JEFE_1V3\n\tGlobal.establecer_texto_accion_tactil("ATRAPAR")'),
}

for fname, (target, repl) in minigame_actions.items():
    fpath = os.path.join(project_dir, fname)
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    if target in content and "Global.establecer_texto_accion_tactil" not in content:
        content = content.replace(target, repl, 1)
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated {fname}")
    else:
        print(f"Skipped {fname} (already updated or target not found)")

# Lobby
lobby_path = os.path.join(project_dir, "lobby.gd")
with open(lobby_path, "r", encoding="utf-8") as f:
    l_content = f.read()
if 'Global.establecer_texto_accion_tactil("")' not in l_content:
    l_content = l_content.replace('func regresar_al_lobby_rpc():', 'func regresar_al_lobby_rpc():\n\tGlobal.establecer_texto_accion_tactil("")')
    with open(lobby_path, "w", encoding="utf-8") as f:
        f.write(l_content)
    print("Updated lobby.gd")
