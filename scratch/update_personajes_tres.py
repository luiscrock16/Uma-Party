import os, re

tres_path = r"e:/PROYECTOS GODOT/Umamusume party/uma-party/recursos/personajes_frames.tres"

with open(tres_path, "r", encoding="utf-8") as f:
    tres_content = f.read()

chars = [
    ('Agnes Tachyon', 'agtc', 'AGTC'),
    ('Dantsu Flame', 'dafl', 'DAFL'),
    ('Jungle Pocket', 'jupc', 'JUPC'),
    ('Samson Big', 'sabg', 'SABG'),
    ('Special Week', 'spwe', 'SPWE')
]

# Find where ext_resources end (before [resource])
resource_idx = tres_content.find("\n[resource]")
if resource_idx == -1:
    resource_idx = tres_content.find("[resource]")

ext_part = tres_content[:resource_idx]
anim_part = tres_content[resource_idx:]

new_ext_lines = []
new_anims_str = []

# Frame map for each character
# We will define ext_resources with id="{pfx}_{frame}"
for char_name, pfx, code in chars:
    frames = [
        # Idle (100)
        "100_00", "100_01", "100_02", "100_03",
        # Caminar (101)
        "101_00", "101_01", "101_02", "101_03", "101_04", "101_05",
        # Correr (102)
        "102_00", "102_01", "102_02", "102_03", "102_04", "102_05",
        # Intro (210)
        "210_00", "210_01", "210_02",
        # Impacto / Aturdido (320)
        "320_00", "320_01", "320_02", "320_03", "320_04", "320_06",
        # Atrapado (340)
        "340_00",
        # Resbalar (330)
        "330_00", "330_01", "330_02",
        # Globo (362)
        "362_00", "362_01",
        # Acierto (730)
        "730_00", "730_01", "730_02", "730_03",
        # Saltar (830)
        "830_00", "830_01", "830_02"
    ]
    
    for f in frames:
        ext_id = f"{pfx}_{f}"
        path = f"res://assets/Sprites/{char_name}/assembled/{pfx}{f}.png"
        new_ext_lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{ext_id}"]')
        
    def make_frames_block(flist):
        items = []
        for fr in flist:
            items.append('{\n"duration": 1.0,\n"texture": ExtResource("%s_%s")\n}' % (pfx, fr))
        return ",\n".join(items)

    char_anims = f''', {{
"frames": [{make_frames_block(["730_00", "730_01", "730_02", "730_03"])}],
"loop": false,
"name": &"{code}_acierto",
"speed": 10.0
}}, {{
"frames": [{make_frames_block(["340_00"])}],
"loop": true,
"name": &"{code}_atrapado",
"speed": 5.0
}}, {{
"frames": [{make_frames_block(["320_04", "320_06"])}],
"loop": true,
"name": &"{code}_aturdido",
"speed": 7.0
}}, {{
"frames": [{make_frames_block(["101_00", "101_01", "101_02", "101_03", "101_04", "101_05"])}],
"loop": true,
"name": &"{code}_caminar",
"speed": 10.0
}}, {{
"frames": [{make_frames_block(["102_00", "102_01", "102_02", "102_03", "102_04", "102_05"])}],
"loop": true,
"name": &"{code}_correr",
"speed": 12.0
}}, {{
"frames": [{make_frames_block(["100_00", "100_01", "100_02", "100_03"])}],
"loop": true,
"name": &"{code}_idle",
"speed": 5.0
}}, {{
"frames": [{make_frames_block(["320_00", "320_01", "320_02", "320_03"])}],
"loop": false,
"name": &"{code}_impacto",
"speed": 10.0
}}, {{
"frames": [{make_frames_block(["210_00", "210_01", "210_02"])}],
"loop": false,
"name": &"{code}_intro",
"speed": 8.0
}}, {{
"frames": [{make_frames_block(["830_00", "830_01", "830_02"])}],
"loop": true,
"name": &"{code}_saltar",
"speed": 10.0
}}, {{
"frames": [{make_frames_block(["362_00", "362_01"])}],
"loop": true,
"name": &"{code}_globo",
"speed": 5.0
}}, {{
"frames": [{make_frames_block(["330_00", "330_01", "330_02"])}],
"loop": true,
"name": &"{code}_resbalar",
"speed": 10.0
}}'''
    new_anims_str.append(char_anims)

# Insert new ext_resources
updated_ext = ext_part.rstrip() + "\n" + "\n".join(new_ext_lines) + "\n"

# In anim_part, the animations list ends with "\n]"
last_bracket_idx = anim_part.rfind("]")
updated_anim = anim_part[:last_bracket_idx].rstrip() + "\n" + "\n".join(new_anims_str) + "\n]\n"

final_content = updated_ext + updated_anim

with open(tres_path, "w", encoding="utf-8") as f:
    f.write(final_content)

print(f"Updated {tres_path} successfully!")
