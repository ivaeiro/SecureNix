#!/bin/bash

#variables
DIR_REPORTES="/home/$SUDO_USER/lynis/reportes"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")


# Banner SecuriNix
VERDE='\033[0;32m'
CIAN='\033[0;36m'
RESET='\033[0m'

clear

printf "${VERDE}"
cat <<'EOF'
  ___  ___  ___  _   _  ___  ___  _  _  ___ __  __
 / __|| __|/ __|| | | || _ \| __|| \| ||_ _|\ \/ /
 \__ \| _|| (__ | |_| ||   /| _| | .` | | |  >  <
 |___/|___|\___| \___/ |_|_\|___||_|\_||___|/_/\_\

EOF
printf "${RESET}"

printf "${CIAN}       LINUX SECURITY HARDENING TOOLKIT${RESET}\n"
printf "${CIAN}             Harden • Audit • Secure${RESET}\n"
echo
echo "              Version 0.1.0"
echo "=============================================="
echo

# Comprobar permisos de root
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Ejecute el script como root."
    echo "        Utilice: sudo $0"
    exit 1
fi

echo "[OK] Permisos de root verificados."

# Comprobar si Lynis está instalado
if command -v lynis > /dev/null 2>&1; then
    echo "[OK] Lynis está instalado."
else
    echo "[AVISO] Lynis no está instalado."
    read -r -p "¿Quieres instalar Lynis? (s/n): " respuesta

    if [[ "$respuesta" == "s" || "$respuesta" == "S" ]]; then
        echo "[INFO] Actualizando lista de paquetes..."
        apt update

        echo "[INFO] Instalando Lynis..."
        apt install -y lynis

        if command -v lynis > /dev/null 2>&1; then
            echo "[OK] Lynis se ha instalado correctamente."
        else
            echo "[ERROR] No se ha podido instalar Lynis."
            exit 1
        fi
    else
        echo "[INFO] Instalación cancelada por el usuario."
        exit 1
    fi
fi

#Creacion del reporte

echo "Creando el reporte del sistema en /home/$SUDO_USER/lynis/reportes..."

mkdir -p $DIR_REPORTES
sudo lynis audit system >> "$DIR_REPORTES/reporte-$TIMESTAMP.txt"
