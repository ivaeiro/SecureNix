!/bin/bash

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


#Comprobacion de actualizaciones del sistema

comprobar_actualizaciones() {
echo
echo "========================================"
echo "    COMPROBACIÓN DE ACTUALIZACIONES"
echo "========================================"

 echo "[+] Actualizando la lista de paquetes..."

if ! apt-get update -qq; then
   echo "[ERROR] No se pudo actualizar la lista de paquetes."
   return 1
fi

echo "[+] Buscando actualizaciones pendientes..."

actualizaciones=$(apt list --upgradable 2>/dev/null | tail -n +2)

if [[ -z "$actualizaciones" ]]; then
  echo "[OK] El sistema está actualizado."
else
cantidad=$(printf '%s\n' "$actualizaciones" | wc -l)

echo "[AVISO] Hay $cantidad paquetes con actualizaciones disponibles."
echo
printf '%s\n' "$actualizaciones"
fi
}



# Separar el reporte más reciente en archivos por módulos
separar_modulos() {
    local REPORTE
    local TIMESTAMP_REPORTE
    local DIR_MODULOS

    # Buscar el reporte original más reciente
    REPORTE=$(find "$DIR_REPORTES" -maxdepth 1 -type f \
        -name 'reporte-*.txt' -printf '%f\n' | sort | tail -n 1)

    if [[ -z "$REPORTE" ]]; then
        echo "[ERROR] No se ha encontrado ningún reporte."
        return 1
    fi

    REPORTE="$DIR_REPORTES/$REPORTE"

    # Obtener la fecha y crear la carpeta de módulos
    TIMESTAMP_REPORTE=$(basename "$REPORTE" .txt)
    TIMESTAMP_REPORTE=${TIMESTAMP_REPORTE#reporte-}
    DIR_MODULOS="$DIR_REPORTES/modulos_$TIMESTAMP_REPORTE"

    mkdir -p "$DIR_MODULOS" || return 1

    echo "[INFO] Reporte seleccionado: $(basename "$REPORTE")"

    # Crear un archivo por cada módulo [+]
    awk -v DIR="$DIR_MODULOS" '
    /^\[\+\]/ {
        if (archivo != "") {
            close(archivo)
        }


        nombre = $0

        # Eliminar códigos de color ANSI
        gsub(/\033\[[0-9;]*m/, "", nombre)

        # Limpiar el encabezado [+]
        sub(/^\[\+\][[:space:]]*/, "", nombre)

        # Limpiar caracteres no válidos para nombres de archivo
        gsub(/[^[:alnum:]_-]/, "_", nombre)

        # Eliminar guiones bajos repetidos al principio y al final
        gsub(/^_+|_+$/, "", nombre)

        archivo = DIR "/" nombre ".txt"
        print $0 > archivo
        next
    }

    archivo != "" {
        print >> archivo
    }

    END {
        if (archivo != "") {
            close(archivo)
        }
    }
    ' "$REPORTE"

    if [[ $? -eq 0 ]]; then
        echo "[OK] Módulos guardados en: $DIR_MODULOS"
        ls -1 "$DIR_MODULOS"
    else
        echo "[ERROR] No se pudieron separar los módulos."
        return 1
    fi
}

# Ejecutar la separación
separar_modulos
