# Dockerfile para Render (Godot 4 Dedicated Headless Server)
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalar librerías mínimas necesarias para Godot Headless en Linux
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    ca-certificates \
    libfontconfig1 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    && rm -rf /var/lib/apt/lists/*

# Descargar binario oficial de Godot 4 Linux Headless
WORKDIR /opt/godot
RUN wget -q https://github.com/godotengine/godot-builds/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip \
    && unzip Godot_v4.3-stable_linux.x86_64.zip \
    && mv Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot \
    && rm Godot_v4.3-stable_linux.x86_64.zip \
    && chmod +x /usr/local/bin/godot

# Copiar el proyecto
WORKDIR /app
COPY . /app

# Exponer puertos comunes (Render asigna dinámicamente $PORT)
EXPOSE 8080 10000

# Variables de entorno por defecto
ENV GODOT_SERVER=1

# Arrancar Godot en modo headless apuntando directamente al lobby como servidor
CMD ["godot", "--headless", "res://escenas/lobby.tscn", "--server"]
