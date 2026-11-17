with open(r'e:/PROYECTOS GODOT/Umamusume party/uma-party/recursos/personajes_frames.tres', 'r', encoding='utf-8') as f:
    text = f.read()

# Let's inspect the last ext_resource id
import re
ext_matches = re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text)
print(f"Total ext_resources: {len(ext_matches)}")
print("Last 5 ext_resources:", ext_matches[-5:])

# Let's inspect how animations are defined
anim_matches = re.findall(r'\{[^{}]*"name": &"MACA_[^}]*\}', text, re.DOTALL)
print(f"Total MACA animations found: {len(anim_matches)}")
for am in anim_matches:
    name_m = re.search(r'"name": &"([^"]+)"', am)
    print("Anim:", name_m.group(1) if name_m else "unknown")
