#!/bin/bash
# Script de dispatcher para NetworkManager - Proyecto Redes III
# Detecta la red activa mediante PING al Gateway y aplica el perfil correcto.

INTERFACE=$1
ACTION=$2

# Solo queremos ejecutar esta lógica cuando detectamos un evento de subida (conexión de cable o comando)
if [ "$ACTION" != "up" ] && [ "$ACTION" != "pre-up" ]; then
    exit 0
fi

# Interfaz sobre la que trabajamos según tu proyecto
TARGET_IF="ens3"

if [ "$INTERFACE" != "$TARGET_IF" ]; then
    exit 0
fi

# Arrays con el orden de prioridad y los gateways asociados
PROFILES=("casa" "clase-eth" "labo-eth")
GATEWAYS=("192.168.1.1" "192.168.226.1" "192.168.223.1")

# Iteramos sobre los perfiles
for i in "${!PROFILES[@]}"; do
    perfil="${PROFILES[$i]}"
    gateway="${GATEWAYS[$i]}"
    
    # 1. Activamos el perfil temporalmente en la interfaz
    nmcli connection up "$perfil" ifname "$INTERFACE" > /dev/null 2>&1
    
    # 2. Damos un margen de un par de segundos para que se asiente la red
    sleep 3
    
    # 3. Lanzamos el PING al gateway (2 paquetes, tiempo máximo de espera 2 segundos)
    if ping -c 2 -W 2 "$gateway" > /dev/null 2>&1; then
        # ¡Bingo! El gateway ha respondido. 
        # La interfaz se queda con este perfil configurado y salimos del script.
        logger -t NetworkManager-Dispatcher "Red '$perfil' detectada correctamente. Perfil aplicado."
        exit 0
    else
        logger -t NetworkManager-Dispatcher "Fallo en red '$perfil'. Probando el siguiente..."
    fi
done

# Si llegamos aquí, es que ninguno de los pings funcionó.
logger -t NetworkManager-Dispatcher "Ninguna red conocida detectada en $TARGET_IF."
# Opcionalmente, podrías apagar la interfaz o poner un perfil por defecto (DHCP)
# nmcli device disconnect "$TARGET_IF"
