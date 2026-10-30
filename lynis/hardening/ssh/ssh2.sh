#!/bin/bash
# hardening/ssh/ssh.sh
# Uso: sudo bash ssh.sh [--audit | --apply]

MODO="${1:---audit}"

[[ $(id -u) -eq 0 ]] || { echo "Ejecute como root"; exit 1; }

# --- Rutas -----------------------------------------------------------------
REPORT_DAT="/var/log/lynis-report.dat"
DROPIN="/etc/ssh/sshd_config.d/00-securenix.conf"
DIR_BACKUP="/var/backups/securenix"

# Solo se aplican solas estas opciones. Lo demás se avisa y se hace a mano.
AJUSTES_SEGUROS="AllowTcpForwarding AllowAgentForwarding ClientAliveCountMax \
LogLevel MaxAuthTries MaxSessions TCPKeepAlive X11Forwarding"

# --- Comprobaciones previas --------------------------------------------------
if ! dpkg -s openssh-server >/dev/null 2>&1; then
    echo "[ERROR] openssh-server no está instalado."
    exit 1
fi
echo "[OK] Servidor SSH instalado."

if systemctl is-active --quiet ssh; then
    echo "[OK] Servicio SSH activo."
else
    echo "[WARNING] Servicio SSH no activo."
fi

[[ -r "$REPORT_DAT" ]] || { echo "[ERROR] No existe $REPORT_DAT. Ejecuta antes: lynis audit system"; exit 1; }

FECHA_REPORTE=$(grep -m1 '^report_datetime_end=' "$REPORT_DAT" | cut -d= -f2)
echo "[OK] Reporte de Lynis: ${FECHA_REPORTE:-fecha desconocida}"
echo

# --- Extraer hallazgos de SSH-7408: salida "opcion|actual|recomendado" --------
parsear_hallazgos() {
    local linea
    local re='field:([^;]*);prefval:([^;]*);value:([^;]*);'
    while IFS= read -r linea; do
        if [[ $linea =~ $re ]]; then
            echo "${BASH_REMATCH[1]}|${BASH_REMATCH[3]}|${BASH_REMATCH[2]}"
        fi
    done < <(grep '^details\[\]=SSH-7408|' "$REPORT_DAT")
}

mapfile -t HALLAZGOS < <(parsear_hallazgos)

# Otras sugerencias SSH que Lynis marca (AllowUsers, AllowGroups...)
mapfile -t OTRAS < <(grep -E '^suggestion\[\]=SSH-(7440|7404|7402|7406)\|' "$REPORT_DAT" | cut -d'|' -f2-3)

if [[ ${#HALLAZGOS[@]} -eq 0 && ${#OTRAS[@]} -eq 0 ]]; then
    echo "[OK] Lynis no propone cambios para SSH."
    exit 0
fi

# --- Auditoría ----------------------------------------------------------------
echo "Mejoras propuestas:"
APLICABLES=()
for h in "${HALLAZGOS[@]}"; do
    IFS='|' read -r clave actual recomendado <<< "$h"
    if [[ -n "$recomendado" && " $AJUSTES_SEGUROS " == *" $clave "* ]]; then
        echo "  [AUTO]   $clave: $actual -> $recomendado"
        APLICABLES+=("$clave $recomendado")
    else
        echo "  [MANUAL] $clave: actual=$actual (Lynis sugiere: ${recomendado:-sin valor concreto})"
    fi
done
for o in "${OTRAS[@]}"; do
    echo "  [MANUAL] $o"
done

if [[ "$MODO" != "--apply" ]]; then
    echo
    echo "Modo auditoría: no se ha cambiado nada. Usa --apply para aplicar los [AUTO]."
    exit 0
fi

[[ ${#APLICABLES[@]} -gt 0 ]] || { echo "Nada que aplicar automáticamente."; exit 0; }

# --- Aplicación ---------------------------------------------------------------
mkdir -p "$DIR_BACKUP"
BACKUP="$DIR_BACKUP/sshd_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"
cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.d "$BACKUP"/
echo "[OK] Backup en $BACKUP"

# Si ya había un drop-in nuestro, lo guardamos para poder restaurarlo
[[ -f "$DROPIN" ]] && cp -a "$DROPIN" "$BACKUP/previo.conf"

{
    echo "# Generado por SecureNix el $(date)"
    printf '%s\n' "${APLICABLES[@]}"
} > "$DROPIN"

if sshd -t; then
    systemctl reload ssh && echo "[OK] Cambios aplicados. Mantén esta sesión abierta y prueba otra."
else
    echo "[ERROR] Configuración inválida, revirtiendo."
    if [[ -f "$BACKUP/previo.conf" ]]; then cp -a "$BACKUP/previo.conf" "$DROPIN"; else rm -f "$DROPIN"; fi
    exit 1
fi
