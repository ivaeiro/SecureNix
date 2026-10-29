#!/bin/bash

if [[ $(id -u) != 0 ]]; then
  echo "Ejecute como root"
  exit 1
fi

#comprobar si ssh esta instalado

# Comprobar si el servidor SSH está instalado
comprobar_ssh_instalado() {
    if dpkg -s openssh-server >/dev/null 2>&1; then
        echo "[OK] El servidor SSH está instalado."
    else
        echo "[WARNING] El servidor SSH no está instalado."
    fi
}

# Comprobar si el servicio SSH está activo
comprobar_ssh_activo() {
    if ! dpkg -s openssh-server >/dev/null 2>&1; then
        echo "[ERROR] No se puede comprobar el servicio: SSH no está instalado."
    elif systemctl is-active --quiet ssh; then
        echo "[OK] El servicio SSH está activo."
    else
        echo "[WARNING] El servicio SSH no está activo."
    fi
}

# Ejecutar las funciones
comprobar_ssh_instalado
comprobar_ssh_activo

#variables
DIR_REPORTES="/home/$SUDO_USER/lynis/reportes"


# Buscar la carpeta de módulos más reciente
DIR_MODULOS=$(find "$DIR_REPORTES" -maxdepth 1 -type d \
    -name 'modulos_*' -printf '%f\n' | sort | tail -n 1)

if [[ -z "$DIR_MODULOS" ]]; then
    echo "[ERROR] No se ha encontrado ninguna carpeta de módulos."
    exit 1
fi

# Buscar el archivo del módulo SSH
ARCHIVO_SSH=$(find "$DIR_REPORTES/$DIR_MODULOS" -maxdepth 1 \
    -type f -iname '*ssh*.txt' -print -quit)

if [[ -z "$ARCHIVO_SSH" ]]; then
    echo "[ERROR] No se ha encontrado el archivo del módulo SSH."
    exit 1
fi

echo "[OK] Archivo SSH encontrado: $ARCHIVO_SSH"
echo
cat "$ARCHIVO_SSH"

sed -i '1,4d' "$ARCHIVO_SSH"
