#!/bin/bash
# Dispatcher Script - Proyecto Redes III
# Comprobación de red mediante Active Probing (Ping a Internet)

INTERFACE=$1
ACTION=$2

# Solo actuamos al levantar la interfaz
if [ "$ACTION" != "up" ]; then
    exit 0
fi

TARGET_IF="ens3"
if [ "$INTERFACE" != "$TARGET_IF" ]; then
    exit 0
fi

# -- PROTECCIÓN ANTI-BUCLES --
# Al cambiar de perfil manualmente, NM lanza otro evento "up". 
# Esto evita que el script se lance infinitas veces.
LOCKFILE="/tmp/nm_dispatcher_${TARGET_IF}_ping.lock"
if [ -f "$LOCKFILE" ]; then
    find "$LOCKFILE" -mmin -1 -quit | grep -q . && exit 0
fi
touch "$LOCKFILE"

# --- ORDEN DE PRIORIDAD DE PERFILES ---
# 1º Universidad (Default) | 2º Casa | 3º Laboratorio
PROFILES=("clase-eth" "casa" "labo-eth")

logger -t NM-Dispatcher "Iniciando secuencia de comprobación de perfiles SD-WAN..."

for perfil in "${PROFILES[@]}"; do
    logger -t NM-Dispatcher "Aplicando perfil '$perfil'..."
    
    # Forzamos el perfil (esto aplica tu IP estática y el gateway automáticamente)
    nmcli connection up "$perfil" ifname "$TARGET_IF" > /dev/null 2>&1
    
    # IMPORTANTE: Damos 4 segundos para que la tabla de enrutamiento se actualice
    sleep 4
    
    logger -t NM-Dispatcher "Comprobando salida a Internet (Ping a 8.8.8.8)..."
    
    # Lanzamos 2 pings a Google con un tiempo máximo de espera de 2 segundos
    if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
        logger -t NM-Dispatcher "¡ÉXITO! El perfil '$perfil' tiene conexión a Internet. Mantenemos esta configuración."
        rm -f "$LOCKFILE"
        exit 0
    else
        logger -t NM-Dispatcher "FALLO: El perfil '$perfil' no llega a Internet. Pasando al siguiente..."
    fi
done

logger -t NM-Dispatcher "Ningún perfil logró salir a Internet. Nos quedamos en el último intentado."
rm -f "$LOCKFILE"
