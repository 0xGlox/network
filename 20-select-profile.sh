#!/bin/bash
# Dispatcher Script - Proyecto Redes III
# Detección infalible por Capa 2 (ARP) para evitar enrutamientos engañosos.

INTERFACE=$1
ACTION=$2

# Solo actuamos cuando una conexión se levanta
if [ "$ACTION" != "up" ]; then
    exit 0
fi

TARGET_IF="ens3"
if [ "$INTERFACE" != "$TARGET_IF" ]; then
    exit 0
fi

# -- PROTECCIÓN ANTI-BUCLES --
# Al cambiar de perfil, NM lanza otro evento "up". Evitamos que el script se ejecute 2 veces.
LOCKFILE="/tmp/nm_dispatcher_${TARGET_IF}.lock"
if [ -f "$LOCKFILE" ]; then
    # Si el candado tiene menos de 1 minuto, salimos (estamos en medio de un cambio automático)
    find "$LOCKFILE" -mmin -1 -quit | grep -q . && exit 0
fi
touch "$LOCKFILE"

# Redes conocidas
PROFILES=("casa" "clase-eth" "labo-eth")
GATEWAYS=("192.168.1.1" "192.168.226.1" "192.168.223.1")

# Averiguamos qué perfil ha levantado NM temporalmente
CURRENT_PROFILE=$(nmcli -t -f GENERAL.CONNECTION device show "$TARGET_IF" | cut -d: -f2)

for i in "${!PROFILES[@]}"; do
    perfil="${PROFILES[$i]}"
    gateway="${GATEWAYS[$i]}"
    
    logger -t NM-Dispatcher "Buscando MAC del gateway $gateway en la red física (ARP)..."
    
    # Lanzamos el dardo ARP (Capa 2). Si la IP no está en este segmento físico, falla de inmediato.
    if arping -c 2 -w 2 -I "$TARGET_IF" "$gateway" > /dev/null 2>&1; then
        logger -t NM-Dispatcher "¡Bingo! Gateway $gateway detectado en Capa 2. La red real es '$perfil'."
        
        # Si NM se equivocó al conectar (ej. puso "casa" por defecto), lo corregimos.
        if [ "$CURRENT_PROFILE" != "$perfil" ]; then
            logger -t NM-Dispatcher "NM aplicó '$CURRENT_PROFILE'. Corrigiendo al perfil correcto: '$perfil'..."
            nmcli connection up "$perfil" ifname "$TARGET_IF"
        else
            logger -t NM-Dispatcher "NM acertó. El perfil activo ($perfil) ya es el correcto."
        fi
        
        # Soltamos el candado y terminamos
        rm -f "$LOCKFILE"
        exit 0
    fi
done

logger -t NM-Dispatcher "Ningún gateway conocido responde a nivel ARP en esta red."
rm -f "$LOCKFILE"
