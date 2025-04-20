#!/bin/bash
# Script para desplegar el BACKEND de MTR Topology Visualizer
# Crea directorios, archivos de código, configuración y servicio systemd.

# --- Configuración ---
INSTALL_DIR="/opt/mtr-topology"
LOG_DIR="/var/log/mtr-topology"
CONFIG_FILE="$INSTALL_DIR/config.json"
AGENTS_FILE="$INSTALL_DIR/agents.json"
SERVICE_NAME="mtr-topology"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
VENV_DIR="$INSTALL_DIR/venv"
REQUIREMENTS_FILE="$INSTALL_DIR/requirements.txt"
APP_USER="mtrtopology"
APP_GROUP="mtrtopology"
PYTHON_CMD="python3"

# --- Funciones Auxiliares ---
print_message() { echo -e "\e[32mINFO:\e[0m $1"; }
print_warning() { echo -e "\e[33mWARN:\e[0m $1"; }
print_error() { echo -e "\e[31mERROR:\e[0m $1"; }

# --- Robustez: Salir en caso de error ---
set -eo pipefail

# --- Verificación Root ---
if [ "$EUID" -ne 0 ]; then
  print_error "Este script debe ejecutarse como root (sudo)."
  exit 1
fi

print_message "Iniciando despliegue del backend de MTR Topology..."

# --- 1. Crear Usuario y Grupo (si no existen) ---
print_message "Asegurando usuario y grupo '$APP_USER'..."
if ! getent group "$APP_GROUP" > /dev/null 2>&1; then
    groupadd --system "$APP_GROUP" || { print_error "Fallo al crear grupo '$APP_GROUP'."; exit 1; }
    print_message "Grupo '$APP_GROUP' creado."
else
    print_message "Grupo '$APP_GROUP' ya existe."
fi
if ! id "$APP_USER" > /dev/null 2>&1; then
    useradd --system --gid "$APP_GROUP" --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin "$APP_USER" || { print_error "Fallo al crear usuario '$APP_USER'."; exit 1; }
    print_message "Usuario '$APP_USER' creado."
else
    # Asegurar que el usuario existente pertenezca al grupo correcto
    if ! groups "$APP_USER" | grep -qw "$APP_GROUP"; then
        usermod -a -G "$APP_GROUP" "$APP_USER" || print_warning "Fallo al añadir usuario existente a grupo '$APP_GROUP'."
    fi
    print_message "Usuario '$APP_USER' ya existe."
fi

# --- 2. Crear Directorios ---
print_message "Creando directorios necesarios..."
# Manejar instalación previa
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Directorio '$INSTALL_DIR' ya existe."
    read -p "¿Detener servicio existente y sobrescribir el directorio? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_error "Instalación cancelada por el usuario."
        exit 0
    fi
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        print_warning "Deteniendo y deshabilitando servicio '$SERVICE_NAME' existente..."
        systemctl stop "$SERVICE_NAME" || true # Ignorar error si no está corriendo
        systemctl disable "$SERVICE_NAME" || true
        sleep 2 # Dar tiempo a que pare
    fi
    print_warning "Eliminando directorio de instalación anterior: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR/core" || { print_error "Fallo al crear $INSTALL_DIR/core."; exit 1; }
mkdir -p "$LOG_DIR" || { print_error "Fallo al crear $LOG_DIR."; exit 1; }
print_message "Directorios creados."

# --- 3. Crear Archivos de Configuración (JSON) ---
print_message "Creando $CONFIG_FILE..."
cat << 'EOF' > "$CONFIG_FILE"
{
  "logging": {
    "log_file": "/var/log/mtr-topology/mtr_topology.log",
    "log_level": "INFO",
    "console": true
  },
  "storage": {
    "host": "localhost",
    "port": 8086,
    "database": "mtr_topology",
    "username": null,
    "password": null,
    "ssl": false,
    "verify_ssl": false,
    "default_tags": {},
    "agents_file": "/opt/mtr-topology/agents.json",
    "influx_timeout": 10
  },
  "mtr": {
    "count": 3,
    "timeout": 1.0,
    "interval": 0.1,
    "max_hops": 30,
    "max_unknown_hops": 3,
    "hop_sleep": 0.05,
    "parallel_jobs": 10,
    "packet_size": 56
  },
  "scan": {
    "scan_interval": 300,
    "scan_on_start": true
  },
  "web": {
    "host": "0.0.0.0",
    "port": 5000,
    "debug": false,
    "secret_key": "!!!GENERATE_A_STRONG_SECRET_KEY_FOR_PRODUCTION!!!"
  }
}
EOF
print_message "$CONFIG_FILE creado."

print_message "Creando archivo de agentes inicial $AGENTS_FILE..."
cat << 'EOF' > "$AGENTS_FILE"
{
  "agents": [
    {
      "address": "8.8.8.8",
      "name": "Google DNS",
      "group": "Internet",
      "enabled": true,
      "options": {}
    },
    {
      "address": "1.1.1.1",
      "name": "Cloudflare DNS",
      "group": "Internet",
      "enabled": true,
      "options": {}
    }
  ]
}
EOF
print_message "$AGENTS_FILE creado."

# --- 4. Crear Archivos de Código Python Backend ---

print_message "Creando archivos Python del backend..."

# ./config.py
cat << 'EOF' > "$INSTALL_DIR/config.py"
#!/usr/bin/env python3
"""
Configuración central para mtr-topology.
"""
import os
import sys
import logging
import json
import threading # <--- Importado
from typing import Dict, Any, Optional
import argparse

# Función setup_logging (sin cambios respecto a la versión anterior)
def setup_logging(
    log_file: str = None, log_level: str = "INFO", console: bool = True
) -> None:
    # ... (código idéntico a la versión anterior)
    numeric_level = getattr(logging, log_level.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError(f'Nivel de log inválido: {log_level}')
    if log_file:
        log_dir = os.path.dirname(log_file)
        if log_dir and not os.path.exists(log_dir):
            try: os.makedirs(log_dir, exist_ok=True)
            except OSError as e: print(f"Error creando logs dir {log_dir}: {e}"); log_file = None
    handlers = []
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    if console:
        ch = logging.StreamHandler(sys.stdout); ch.setFormatter(formatter); handlers.append(ch)
    if log_file:
        try: fh = logging.FileHandler(log_file); fh.setFormatter(formatter); handlers.append(fh)
        except Exception as e: print(f"Fallo al crear log file handler {log_file}: {e}")
    logging.basicConfig(level=numeric_level, handlers=handlers, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logging.getLogger('werkzeug').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('influxdb').setLevel(logging.WARNING)


class Config:
    """Clase singleton para manejar la configuración global de forma thread-safe."""
    _instance: Optional["Config"] = None
    _lock: threading.RLock = threading.RLock() # Lock para proteger acceso a _data

    # Implementación Singleton
    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            with cls._lock:
                # Doble check por si otro hilo lo creó mientras esperábamos el lock
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False # Flag para inicializar solo una vez
        return cls._instance

    def __init__(self, config_file: Optional[str] = None):
        """Inicializa la configuración (solo la primera vez que se llama)."""
        if hasattr(self, '_initialized') and self._initialized: return # Ya inicializado por otra llamada

        with self._lock: # Proteger inicialización
            if hasattr(self, '_initialized') and self._initialized: return # Doble check dentro del lock

            # Valores por defecto (iguales que antes)
            self._data = {
                'app_name': 'mtr-topology', 'debug': False,
                'logging': {'log_file': '/opt/mtr-topology/log/mtr_topology.log', 'log_level': 'INFO', 'console': True},
                'mtr': {'count': 3, 'timeout': 1.0, 'interval': 0.1, 'max_hops': 30, 'max_unknown_hops': 3, 'hop_sleep': 0.05, 'parallel_jobs': 10, 'packet_size': 56},
                'storage': {'host': 'localhost', 'port': 8086, 'username': None, 'password': None, 'database': 'mtr_topology', 'ssl': False, 'verify_ssl': False, 'default_tags': {}, 'agents_file': '/opt/mtr-topology/agents.json', 'influx_timeout': 10},
                'web': {'host': '0.0.0.0', 'port': 5000, 'debug': False, 'secret_key': '!!!GENERATE_A_STRONG_SECRET_KEY_FOR_PRODUCTION!!!'},
                'scan': {'scan_interval': 300, 'scan_on_start': True}
            }
            self._config_file_path = config_file # Guardar path para posible recarga

            if config_file:
                self.load_from_file(config_file)

            self._initialized = True # Marcar como inicializado

    def load_from_file(self, config_file: str) -> None:
        """Carga (o recarga) configuración desde archivo JSON."""
        try:
            with open(config_file, 'r') as f:
                file_config = json.load(f)
            with self._lock:
                self._update_dict(self._data, file_config)
            self._config_file_path = config_file # Actualizar path si cambia
            logging.info(f"Configuración cargada/recargada desde {config_file}")
        except FileNotFoundError:
             logging.warning(f"Archivo config '{config_file}' no encontrado. Usando configuración actual/default.")
        except json.JSONDecodeError as e:
             logging.error(f"Error decodificando '{config_file}': {e}. Configuración NO actualizada.")
        except Exception as e:
            logging.error(f"Error inesperado cargando '{config_file}': {e}. Configuración NO actualizada.")

    def _update_dict(self, base: Dict, update: Dict): # Método recursivo interno
        for key, value in update.items():
            if isinstance(base.get(key), dict) and isinstance(value, dict):
                self._update_dict(base[key], value)
            else:
                base[key] = value

    def get(self, key: str, default: Any = None) -> Any:
        """Obtiene un valor de configuración (thread-safe)."""
        with self._lock:
            keys = key.split('.')
            value = self._data
            try:
                for k in keys: value = value[k]
                return value
            except (KeyError, TypeError): return default

    def set(self, key: str, value: Any) -> None:
        """Establece un valor de configuración (thread-safe)."""
        with self._lock:
            keys = key.split('.')
            level = self._data
            for k in keys[:-1]:
                level = level.setdefault(k, {})
                if not isinstance(level, dict): # Prevenir error si clave intermedia no es dict
                     logging.error(f"Conflicto de configuración: intentando establecer subclave '{keys[-1]}' en valor no-diccionario para '{'.'.join(keys[:-1])}'")
                     return
            level[keys[-1]] = value
            logging.debug(f"Config set: {key} = {value}")

    def to_dict(self) -> Dict[str, Any]:
        """Devuelve una copia de la configuración (thread-safe)."""
        with self._lock:
            # Usar json dumps/loads para copia profunda simple y segura
            return json.loads(json.dumps(self._data))

# Instancia Singleton Global
# Se inicializa explícitamente en load_from_args o la primera vez que se accede
config: Optional[Config] = None

def load_from_args(argv=None) -> Config:
    """Carga configuración desde args y archivo (inicializa singleton)."""
    global config
    parser = argparse.ArgumentParser(description='MTR Topology Service')
    parser.add_argument('--config', '-c', type=str, default='/opt/mtr-topology/config.json', help='Ruta al archivo config.json')
    parser.add_argument('--debug', '-d', action='store_true', help='Habilitar modo debug')
    # Añadir más argumentos si se necesitan para sobrescribir config
    parser.add_argument('--log-file', type=str, help='Ruta archivo log (sobrescribe config)')
    parser.add_argument('--log-level', type=str, choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], help='Nivel logging (sobrescribe config)')
    parser.add_argument('--port', '-p', type=int, help='Puerto API web (sobrescribe config)')
    parser.add_argument('--host', type=str, help='Host API web (sobrescribe config)')

    parsed_args = parser.parse_args(argv)

    # Inicializar el singleton Config con el archivo especificado (o default)
    if config is None: # Solo inicializar si no existe
         config = Config(parsed_args.config)
    else: # Si ya existe (raro, pero posible), recargar desde archivo si se especificó
         if parsed_args.config != config._config_file_path:
              config.load_from_file(parsed_args.config)

    # Sobrescribir valores con argumentos CLI
    if parsed_args.debug:
        config.set('debug', True)
        config.set('logging.log_level', 'DEBUG')
        config.set('web.debug', True)
        print("Modo DEBUG habilitado via argumento.")
    if parsed_args.log_level: config.set('logging.log_level', parsed_args.log_level)
    if parsed_args.log_file: config.set('logging.log_file', parsed_args.log_file)
    if parsed_args.port: config.set('web.port', parsed_args.port)
    if parsed_args.host: config.set('web.host', parsed_args.host)

    # Configurar logging DESPUÉS de cargar toda la configuración
    setup_logging(
        log_file=config.get('logging.log_file'),
        log_level=config.get('logging.log_level'),
        console=config.get('logging.console')
    )
    logging.info("Configuración y logging inicializados/actualizados.")
    return config
EOF

# ./core/__init__.py
touch "$INSTALL_DIR/core/__init__.py"

# ./core/icmp.py
cat << 'EOF' > "$INSTALL_DIR/core/icmp.py"
#!/usr/bin/env python3
"""
Módulo ICMP para mtr-topology.
"""
# ... (código idéntico a la versión anterior corregida)
import socket, struct, time, random, select, logging, os
from typing import Tuple, Dict, Optional, Union, List

logger = logging.getLogger(__name__)
ICMP_ECHO_REQUEST = 8; ICMP_ECHO_REPLY = 0; ICMP_TIME_EXCEEDED = 11; ICMP_DEST_UNREACH = 3
ICMPV6_ECHO_REQUEST = 128; ICMPV6_ECHO_REPLY = 129; ICMPV6_TIME_EXCEEDED = 3; ICMPV6_DEST_UNREACH = 1

class ICMPError(Exception): pass
class ICMPPermissionError(ICMPError): pass
class ICMPNetworkError(ICMPError): pass
class ICMPTimeoutError(ICMPError): pass

def checksum(source_string: bytes) -> int:
    # ... (checksum implementation) ...
    sum_val = 0; count_to = (len(source_string) // 2) * 2
    for count in range(0, count_to, 2): sum_val += source_string[count+1]*256+source_string[count]; sum_val &= 0xffffffff
    if count_to < len(source_string): sum_val += source_string[len(source_string)-1]; sum_val &= 0xffffffff
    sum_val = (sum_val>>16) + (sum_val&0xffff); sum_val += (sum_val>>16)
    return ~sum_val&0xffff

def create_icmp_packet(packet_id: int, seq_num: int, data_size: int = 56) -> bytes:
    header = struct.pack('!BBHHH', ICMP_ECHO_REQUEST, 0, 0, packet_id, seq_num)
    timestamp = struct.pack('!d', time.time())
    padding_size = max(0, data_size - len(timestamp))
    data = timestamp + (b'Q' * padding_size)
    my_checksum = checksum(header + data)
    header = struct.pack('!BBHHH', ICMP_ECHO_REQUEST, 0, socket.htons(my_checksum), packet_id, seq_num)
    return header + data

def create_icmpv6_packet(packet_id: int, seq_num: int, data_size: int = 56) -> bytes:
    header = struct.pack('!BBHHH', ICMPV6_ECHO_REQUEST, 0, 0, packet_id, seq_num)
    timestamp = struct.pack('!d', time.time())
    padding_size = max(0, data_size - len(timestamp))
    data = timestamp + (b'Q' * padding_size)
    # Checksum calculado por kernel para ICMPv6 raw sockets
    # header = struct.pack('!BBHHH', ICMPV6_ECHO_REQUEST, 0, socket.htons(checksum), packet_id, seq_num)
    return header + data

def parse_ipv4_header(packet: bytes) -> Optional[Dict]:
    if len(packet) < 20: return None
    fields = struct.unpack('!BBHHHBBHII', packet[:20])
    ihl = (fields[0] & 0x0F) * 4
    src_ip = socket.inet_ntoa(packet[12:16]); dst_ip = socket.inet_ntoa(packet[16:20])
    return {'ihl': ihl, 'src_ip': src_ip, 'dst_ip': dst_ip, 'proto': fields[6]}

def parse_icmp_reply(packet: bytes, expected_id: int, expected_seq: int) -> Tuple[Optional[str], Optional[float], Optional[str]]:
    ip_header = parse_ipv4_header(packet)
    if not ip_header or ip_header['proto'] != socket.IPPROTO_ICMP: return None, None, None
    icmp_packet = packet[ip_header['ihl']:]
    if len(icmp_packet) < 8: return None, None, None
    icmp_type, icmp_code, _, packet_id, packet_seq = struct.unpack('!BBHHH', icmp_packet[:8])
    response_ip = ip_header['src_ip']; rtt = None; response_type = 'unknown'
    if icmp_type == ICMP_ECHO_REPLY:
        response_type = 'echo_reply'
        if packet_id == expected_id and packet_seq == expected_seq:
            if len(icmp_packet) >= 16: # Header + Timestamp
                try: rtt = (time.time() - struct.unpack('!d', icmp_packet[8:16])[0]) * 1000
                except struct.error: pass
            return response_ip, rtt, response_type
        else: return None, None, None # ID/Seq mismatch
    elif icmp_type == ICMP_TIME_EXCEEDED:
        response_type = 'time_exceeded'
        if len(icmp_packet) >= 36: # ICMP Hdr(8) + Orig IP Hdr(20) + Orig ICMP Hdr(8)
            try:
                orig_id, orig_seq = struct.unpack('!HH', icmp_packet[32:36]) # Offset 8+20+4
                if orig_id == expected_id and orig_seq == expected_seq: return response_ip, rtt, response_type
            except struct.error: pass
        return None, None, None # Original packet not ours or truncated
    elif icmp_type == ICMP_DEST_UNREACH:
         response_type = f'unreachable_code_{icmp_code}'
         if len(icmp_packet) >= 36:
             try:
                 orig_id, orig_seq = struct.unpack('!HH', icmp_packet[32:36])
                 if orig_id == expected_id and orig_seq == expected_seq: return response_ip, rtt, response_type
             except struct.error: pass
         return None, None, None
    else: return None, None, None # Other types ignored

def parse_icmpv6_reply(packet: bytes, expected_id: int, expected_seq: int) -> Tuple[Optional[str], Optional[float], Optional[str]]:
    if len(packet) < 8: return None, None, None
    icmp_type, icmp_code, _, packet_id, packet_seq = struct.unpack('!BBHHH', packet[:8])
    rtt = None; response_type = 'unknown'
    if icmp_type == ICMPV6_ECHO_REPLY:
        response_type = 'echo_reply'
        if packet_id == expected_id and packet_seq == expected_seq:
            if len(packet) >= 16: # Header + Timestamp
                try: rtt = (time.time() - struct.unpack('!d', packet[8:16])[0]) * 1000
                except struct.error: pass
            return '', rtt, response_type # IP comes from recvfrom addr tuple
        else: return None, None, None # ID/Seq mismatch
    elif icmp_type == ICMPV6_TIME_EXCEEDED:
        response_type = 'time_exceeded'
        # Proper check requires parsing encapsulated headers, simplified for traceroute context
        # Assuming it's for our packet if we get Time Exceeded
        return '', rtt, response_type
    elif icmp_type == ICMPV6_DEST_UNREACH:
         response_type = f'unreachable_code_{icmp_code}'
         # Simplified check
         return '', rtt, response_type
    else: return None, None, None

def send_receive_icmp(
    destination_addr: str, ttl: int = 64, timeout: float = 1.0,
    packet_size: int = 56, packet_id: Optional[int] = None, seq_num: Optional[int] = None
) -> Tuple[Optional[str], Optional[float], Optional[str]]:
    addr_family = socket.AF_INET
    try: socket.inet_pton(socket.AF_INET, destination_addr)
    except socket.error:
        try: socket.inet_pton(socket.AF_INET6, destination_addr); addr_family = socket.AF_INET6
        except socket.error:
             try:
                 addr_info = socket.getaddrinfo(destination_addr, None, socket.AF_UNSPEC, socket.SOCK_DGRAM)
                 if not addr_info: raise ICMPNetworkError(f"Cannot resolve address (getaddrinfo empty): {destination_addr}")
                 addr_family = addr_info[0][0]
                 destination_addr = addr_info[0][4][0] # Use resolved IP
                 logger.debug(f"Resolved '{destination_addr}' to {destination_addr} (Family: {addr_family})")
             except socket.gaierror: raise ICMPNetworkError(f"Cannot resolve address: {destination_addr}")

    current_pid = os.getpid() & 0xFFFF
    if packet_id is None: packet_id = current_pid
    if seq_num is None: seq_num = int(time.time() * 10) & 0xFFFF

    icmp_proto = socket.IPPROTO_ICMP if addr_family == socket.AF_INET else socket.IPPROTO_ICMPV6
    create_func = create_icmp_packet if addr_family == socket.AF_INET else create_icmpv6_packet
    parse_func = parse_icmp_reply if addr_family == socket.AF_INET else parse_icmpv6_reply
    icmp_socket = None
    try:
        icmp_socket = socket.socket(addr_family, socket.SOCK_RAW, icmp_proto)
        if addr_family == socket.AF_INET: icmp_socket.setsockopt(socket.IPPROTO_IP, socket.IP_TTL, ttl)
        else: icmp_socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_UNICAST_HOPS, ttl)
        icmp_socket.settimeout(timeout)
        packet = create_func(packet_id, seq_num, packet_size)
        send_time = time.time()
        if addr_family == socket.AF_INET: icmp_socket.sendto(packet, (destination_addr, 0))
        else: icmp_socket.sendto(packet, (destination_addr, 0, 0, 0))

        while True:
            time_left = timeout - (time.time() - send_time)
            if time_left <= 0: return None, None, 'timeout'
            ready = select.select([icmp_socket], [], [], time_left)
            if not ready[0]: return None, None, 'timeout'
            try:
                 recv_packet, addr = icmp_socket.recvfrom(1024)
                 receive_time = time.time()
                 responder_ip_parsed, rtt_ms, response_type = parse_func(recv_packet, packet_id, seq_num)
                 if response_type: # Got a valid ICMP packet type we understand
                     actual_responder_ip = addr[0]
                     # If parse_func didn't get RTT (e.g., Time Exceeded), calculate it now
                     if rtt_ms is None: rtt_ms = (receive_time - send_time) * 1000
                     # Check if it's a direct reply matching ID/Seq OR a TimeExceeded/Unreachable presumably for our probe
                     if responder_ip_parsed is not None or response_type in ['time_exceeded'] or 'unreachable' in response_type:
                         logger.debug(f"Recv {response_type} from {actual_responder_ip} for {destination_addr} (ttl={ttl}), rtt={rtt_ms:.2f}ms")
                         return actual_responder_ip, rtt_ms, response_type
                     else: # Recognized type, but not matching ID/Seq (e.g., different ping reply)
                          logger.debug(f"Ignored {response_type} from {actual_responder_ip} (ID/Seq mismatch).")
                 # else: Packet wasn't ICMP or couldn't be parsed, continue waiting
            except socket.timeout: return None, None, 'timeout'
            except Exception as e: logger.error(f"Error recv/parse ICMP: {e}") # Continue waiting

    except socket.error as e:
        if e.errno in [1, 13]: raise ICMPPermissionError("Root privileges required for raw sockets.")
        elif e.errno in [101, 65]: return None, None, 'network_unreachable' # Network Unreachable / No route to host
        else: logger.error(f"ICMP socket error (errno {e.errno}): {e}"); return None, None, f'error_socket_{e.errno}'
    except Exception as e: logger.error(f"Unexpected ICMP error: {e}"); return None, None, 'error_unknown'
    finally:
        if icmp_socket: icmp_socket.close()
EOF

# ./core/mtr.py
cat << 'EOF' > "$INSTALL_DIR/core/mtr.py"
#!/usr/bin/env python3
"""
Módulo MTR para mtr-topology.
"""
import time, logging, threading, queue, random, socket, os # <-- os importado
from typing import List, Dict, Any, Optional, Tuple, Union, Set, TYPE_CHECKING
from dataclasses import dataclass, field

from .icmp import send_receive_icmp, ICMPPermissionError, ICMPNetworkError
if TYPE_CHECKING:
    from .storage import InfluxStorage # <-- Uso de TYPE_CHECKING

logger = logging.getLogger(__name__)

# --- Clases HopResult y MTRResult (sin cambios funcionales) ---
@dataclass
class HopResult:
    hop_number: int; ip_address: Optional[str] = None
    responses: List[Tuple[Optional[float], str]] = field(default_factory=list); sent_count: int = 0
    @property
    def received_count(self) -> int: return sum(1 for r,t in self.responses if t not in ['timeout','error','permission_error', 'network_unreachable'] and not t.startswith('error_socket'))
    @property
    def successful_pings(self) -> List[float]: return [r for r,t in self.responses if r is not None and t not in ['timeout','error','permission_error', 'network_unreachable'] and not t.startswith('error_socket')]
    @property
    def avg_latency(self) -> Optional[float]: p=self.successful_pings; return sum(p)/len(p) if p else None
    @property
    def min_latency(self) -> Optional[float]: p=self.successful_pings; return min(p) if p else None
    @property
    def max_latency(self) -> Optional[float]: p=self.successful_pings; return max(p) if p else None
    @property
    def packet_loss(self) -> float:
        if self.sent_count==0: return 0.0
        lost=sum(1 for r,t in self.responses if t in ['timeout','error','permission_error', 'network_unreachable'] or t.startswith('error_socket')); return (lost/self.sent_count)*100.0
    @property
    def response_types_summary(self) -> Dict[str,int]: s={}; [s.update({t:s.get(t,0)+1}) for _,t in self.responses]; return s
    def to_dict(self) -> Dict[str, Any]: return {'hop_number':self.hop_number, 'ip_address':self.ip_address, 'avg_latency':self.avg_latency, 'min_latency':self.min_latency, 'max_latency':self.max_latency, 'sent_count':self.sent_count, 'received_count':self.received_count, 'packet_loss':self.packet_loss, 'response_types_summary':self.response_types_summary}

@dataclass
class MTRResult:
    destination: str; source: str = "unknown"; start_time: float = field(default_factory=time.time)
    end_time: Optional[float]=None; hops: List[HopResult]=field(default_factory=list)
    status: str="pending"; error: Optional[str]=None
    def add_hop(self, hop:HopResult): self.hops.append(hop)
    def complete(self, status:str="completed", error:Optional[str]=None): self.end_time=time.time(); self.status=status; self.error=error
    @property
    def duration(self)->Optional[float]: return self.end_time-self.start_time if self.end_time else None
    def to_dict(self)->Dict[str, Any]: return {'destination':self.destination, 'source':self.source, 'start_time':self.start_time, 'end_time':self.end_time, 'duration':self.duration, 'status':self.status, 'error':self.error, 'hops':[h.to_dict() for h in self.hops]}
# --- Fin Clases Data ---

class MTRRunner:
    """Ejecuta MTR y gestiona trabajos."""
    def __init__(self, storage: "InfluxStorage"): # String hint para storage
        self.storage = storage
        self.default_options = {'count':3,'timeout':1.0,'interval':0.1,'max_hops':30,'max_unknown_hops':3,'hop_sleep':0.05,'packet_size':56}
        self.scan_jobs = queue.Queue()
        self.scan_threads: List[threading.Thread] = []
        self.running = False
        self.stop_event = threading.Event()
        self.pid = os.getpid() # <--- os.getpid() ahora funciona
        self._worker_count = 0
        self._active_targets: Set[str] = set() # <-- Gestión de targets activos
        self._active_targets_lock = threading.RLock()

    def set_options(self, options: Dict[str, Any]): self.default_options.update(options); logger.info(f"Opciones MTR: {self.default_options}")

    def _get_source_ip(self, destination: str) -> str:
        # --- Lógica _get_source_ip corregida ---
        dest_is_ipv6 = ':' in destination
        family_to_try = socket.AF_INET6 if dest_is_ipv6 else socket.AF_INET
        fallback_family = socket.AF_INET if dest_is_ipv6 else socket.AF_INET6
        # Usar un destino de prueba válido para el fallback
        test_dest = "8.8.8.8" if fallback_family == socket.AF_INET else "2001:4860:4860::8888"
        s = None # Inicializar
        try:
            s = socket.socket(family_to_try, socket.SOCK_DGRAM)
            s.connect((destination, 80)) # Conectar al destino real con la familia correcta
            source_ip = s.getsockname()[0]
            return source_ip.split('%')[0] # Remover posible %scope_id en IPv6
        except Exception as e_primary:
            logger.warning(f"Fallo al determinar IP origen ({socket.AddressFamily(family_to_try).name}) para {destination}: {e_primary}. Intentando fallback...")
            try:
                 s = socket.socket(fallback_family, socket.SOCK_DGRAM)
                 s.connect((test_dest, 80)) # Conectar a destino de prueba con familia fallback
                 source_ip = s.getsockname()[0]
                 return source_ip.split('%')[0]
            except Exception as e_fallback:
                 logger.error(f"Fallo fallback ({socket.AddressFamily(fallback_family).name}) para determinar IP origen: {e_fallback}")
                 # Devolver loopback como último recurso seguro
                 return "127.0.0.1" if family_to_try == socket.AF_INET else "::1"
        finally:
             if s: s.close()
        # --- Fin corrección _get_source_ip ---

    # --- Métodos Gestión Targets ---
    def add_target(self, address: str):
        """Marca un target como activo para ser escaneado."""
        with self._active_targets_lock: self._active_targets.add(address)
        logger.info(f"Target '{address}' marcado activo.")
    def remove_target(self, address: str):
        """Marca un target como inactivo y cancela sus trabajos pendientes."""
        removed = False
        with self._active_targets_lock:
            if address in self._active_targets:
                 self._active_targets.remove(address)
                 removed = True
        if removed: logger.info(f"Target '{address}' marcado inactivo.")
        else: logger.debug(f"Intento de inactivar target no activo: {address}")
        self.cancel_pending_scans(address) # Cancelar trabajos pendientes

    def get_active_targets(self) -> List[str]:
         """Obtiene una copia de la lista de targets activos."""
         with self._active_targets_lock: return list(self._active_targets)
    # --- Fin Gestión Targets ---

    def trace_route(self, destination: str, options: Optional[Dict[str, Any]] = None) -> Optional[MTRResult]:
        # --- Verificación de target activo ---
        with self._active_targets_lock:
            if destination not in self._active_targets:
                logger.debug(f"Omitiendo trace_route para target inactivo: {destination}")
                return None
        # --- Fin Verificación ---
        run_options = {**self.default_options, **(options or {})}
        result = MTRResult(destination=destination); result.status = "running"
        try: # --- Resolución DNS antes de empezar ---
             # Usar getaddrinfo para manejar IPv4/IPv6 y obtener IP canónica
             addr_info = socket.getaddrinfo(destination, None, socket.AF_UNSPEC, socket.SOCK_DGRAM)
             final_destination_ip = addr_info[0][4][0]; result.destination = final_destination_ip
             logger.debug(f"Target '{destination}' resuelto a {final_destination_ip}")
        except socket.gaierror: result.complete(status="error", error=f"Cannot resolve host: {destination}"); self._save_result(result); return result
        except Exception as e: result.complete(status="error", error=f"Unexpected resolution error: {e}"); self._save_result(result); return result

        result.source = self._get_source_ip(result.destination)
        logger.info(f"Iniciando MTR: {result.source} -> {result.destination} (PID: {self.pid})")
        consecutive_unknown=0; last_hop_ip=None; packet_seq=random.randint(1,1000)
        for ttl in range(1, run_options['max_hops']+1):
             if self.stop_event.is_set(): result.complete(status="aborted",error="Service stopped"); break
             # Re-verificar si el target sigue activo DENTRO del loop de TTLs
             with self._active_targets_lock:
                 if destination not in self._active_targets:
                     result.complete(status="aborted",error="Target disabled during scan"); break

             hop_result = HopResult(hop_number=ttl); hop_responded=False; current_hop_ip=None
             for i in range(run_options['count']):
                  if self.stop_event.is_set(): break
                  with self._active_targets_lock: # Check activo ANTES de cada ping
                      if destination not in self._active_targets: break

                  hop_result.sent_count+=1; packet_seq+=1; seq_num=packet_seq&0xFFFF; packet_id=(self.pid^ttl^i)&0xFFFF
                  try:
                       responder_ip, rtt_ms, resp_type = send_receive_icmp(result.destination, ttl, run_options['timeout'], run_options['packet_size'], packet_id, seq_num)
                       hop_result.responses.append((rtt_ms, resp_type))
                       if responder_ip:
                            hop_responded=True
                            if hop_result.ip_address is None: hop_result.ip_address = responder_ip
                            # Si es una respuesta directa del destino final, podemos parar este TTL
                            if resp_type == 'echo_reply' and responder_ip == result.destination:
                                last_hop_ip=responder_ip; break # Salir del loop de pings para este TTL
                       elif resp_type == 'permission_error': raise ICMPPermissionError("Permission denied")
                       elif resp_type == 'network_unreachable':
                            logger.warning(f"MTR {result.destination} TTL {ttl}: Network Unreachable")
                            # Considerar esto como fin si ocurre consistentemente? Por ahora solo log.
                       # Otros errores (timeout, socket error) ya añaden 'timeout' o 'error_socket_X'
                  except ICMPPermissionError as e: result.complete(status="permission_error",error=str(e)); self._save_result(result); return result
                  except (ICMPNetworkError, Exception) as e:
                      logger.error(f"MTR Error {result.destination} TTL {ttl} Attempt {i+1}: {e}", exc_info=True)
                      hop_result.responses.append((None, 'error')) # Añadir 'error' genérico

                  # Salir si el target fue desactivado durante los pings de este TTL
                  with self._active_targets_lock:
                       if destination not in self._active_targets: break
                  if i < run_options['count']-1: time.sleep(run_options['interval'])
             # Fin loop pings TTL

             if self.stop_event.is_set() or (destination not in self._active_targets): break # Salir del loop TTL si se detuvo/desactivó

             result.add_hop(hop_result)
             if not hop_responded or hop_result.ip_address is None: consecutive_unknown+=1; logger.debug(f"Hop {ttl} no response for {destination}.")
             else: consecutive_unknown=0

             # Comprobar si *algún* ping llegó al destino final en este TTL
             if last_hop_ip == result.destination: logger.debug(f"Destination {result.destination} reached at TTL {ttl}."); break

             # Salir si demasiados hops consecutivos sin respuesta
             if consecutive_unknown >= run_options['max_unknown_hops']: logger.warning(f"MTR {destination}: Max {run_options['max_unknown_hops']} unknown hops reached at TTL {ttl}. Aborting trace."); break

             time.sleep(run_options['hop_sleep']) # Pausa entre TTLs
        # Fin loop TTLs

        # Marcar como completado si no se abortó antes
        if result.status == "running": result.complete(status="completed")

        self._save_result(result)
        logger.info(f"MTR {result.destination} finished: {result.status}")
        return result

    def _save_result(self, result: "MTRResult"): # String hint
        if self.storage:
            try:
                if not self.storage.store_mtr_result(result): logger.error(f"Failed to save MTR result for {result.destination}")
            except Exception as e: logger.error(f"Exception saving MTR result for {result.destination}: {e}", exc_info=True)
        else: logger.warning("Storage not configured, result not saved.")

    def _worker(self, worker_id: int):
        logger.info(f"Worker {worker_id} started.")
        while not self.stop_event.is_set():
            destination = None
            options = None
            try:
                destination, options = self.scan_jobs.get(timeout=1.0)
                is_active = False # Default a no activo
                with self._active_targets_lock: is_active = destination in self._active_targets
                if is_active:
                     logger.debug(f"Worker {worker_id} processing {destination}")
                     mtr_result = self.trace_route(destination, options) # Puede retornar None si se desactiva mientras corre
                     if mtr_result: logger.debug(f"Worker {worker_id} completed MTR {destination}: {mtr_result.status}")
                     else: logger.debug(f"Worker {worker_id} skipped or aborted MTR {destination} (inactive).")
                else: logger.debug(f"Worker {worker_id} skipping {destination} (inactive).")
                self.scan_jobs.task_done() # Marcar como hecho SIEMPRE que se saque de la cola
            except queue.Empty: continue
            except Exception as e:
                logger.error(f"Worker {worker_id} error processing {destination or 'job'}: {e}", exc_info=True)
                if destination: # Marcar como hecho si falló después de obtenerlo
                     try: self.scan_jobs.task_done()
                     except ValueError: pass # Ignorar si ya se hizo
        logger.info(f"Worker {worker_id} stopped.")

    def start_scan_loop(self, parallel_jobs: int):
        if self.running: logger.warning("Scan loop already running."); return
        self.running = True; self.stop_event.clear(); self._worker_count=0; self.scan_threads=[]
        num_workers = max(1, int(parallel_jobs)) # Asegurar al menos 1
        logger.info(f"Starting scan loop ({num_workers} workers)...")
        for i in range(num_workers):
            self._worker_count+=1; t = threading.Thread(target=self._worker, args=(self._worker_count,), daemon=True, name=f"MTRWorker-{self._worker_count}"); t.start(); self.scan_threads.append(t)
        logger.info(f"Scan loop started with {len(self.scan_threads)} workers.")

    def stop_scan_loop(self, wait: bool = True):
        if not self.running: logger.warning("Scan loop not running."); return
        logger.info("Stopping scan loop...")
        self.running=False; self.stop_event.set()

        # Limpiar cola para join rápido si wait=False O para informar si wait=True
        pending_jobs=[]; count=0
        while not self.scan_jobs.empty():
            try: pending_jobs.append(self.scan_jobs.get_nowait()); count+=1
            except queue.Empty: break
        if count > 0:
             logger.warning(f"Discarded {count} pending jobs on stop.")
             # Marcar todos como hechos para que join() no se bloquee
             for _ in pending_jobs:
                 try: self.scan_jobs.task_done()
                 except ValueError: pass

        if wait:
            logger.info("Waiting for active worker tasks to finish...")
            # No necesitamos join a la cola si la vaciamos, join a los threads es suficiente
            # self.scan_jobs.join() # Puede bloquear si no se vació/marcó bien
        else:
            logger.info("Not waiting for active tasks (wait=False).")

        logger.info("Waiting for worker threads to exit...")
        join_timeout = 10.0 # Aumentar timeout
        for t in self.scan_threads:
            if t.is_alive(): t.join(timeout=join_timeout)
            if t.is_alive(): logger.warning(f"Worker thread {t.name} did not finish within {join_timeout}s.")

        self.scan_threads=[]
        logger.info("Scan loop stopped.")

    def schedule_scan(self, destination: str, options: Optional[Dict[str, Any]] = None) -> bool:
        if not self.running: logger.error("Cannot schedule scan: loop not running."); return False
        # Programar solo si está activo
        with self._active_targets_lock:
             if destination not in self._active_targets: logger.debug(f"Skipping schedule for inactive target: {destination}"); return False
        try:
            # Evitar duplicados si ya está en la cola? Depende del caso de uso.
            # Por ahora, permitimos múltiples escaneos programados.
            self.scan_jobs.put((destination, options));
            logger.debug(f"Scheduled scan for {destination}. Queue size: {self.scan_jobs.qsize()}");
            return True
        except Exception as e: logger.error(f"Failed to schedule scan for {destination}: {e}"); return False

    def schedule_scan_all(self, agents: List[Dict[str, Any]], randomize_interval: bool = True):
        if not self.running: logger.error("Cannot schedule all: loop not running."); return
        scheduled=0; skipped=0
        active_targets_now = self.get_active_targets() # Obtener lista actual de targets ACTIVOS en el runner
        logger.info(f"Scheduling scans for {len(agents)} agents against {len(active_targets_now)} active targets...")

        for agent in agents:
            if self.stop_event.is_set(): logger.info("Mass schedule aborted by stop signal."); break
            addr = agent.get('address'); enabled = agent.get('enabled', True); opts = agent.get('options')

            # Skip si no hay address, no está habilitado en la config, O no está en el set de targets activos del runner
            if not addr or not enabled or (addr not in active_targets_now):
                if addr and enabled and (addr not in active_targets_now):
                     logger.debug(f"Skipping schedule for {addr}: Enabled but not currently active in runner.")
                elif addr and not enabled:
                     logger.debug(f"Skipping schedule for {addr}: Disabled.")
                skipped+=1; continue

            if self.schedule_scan(addr, opts): scheduled+=1
            else: skipped+=1 # Si schedule_scan falla

            if randomize_interval and len(agents)>1:
                sleep_time = random.uniform(0.05, 0.3)
                # Usar wait() para responder al stop_event durante el sleep
                if self.stop_event.wait(sleep_time):
                     logger.info("Mass schedule randomization interrupted by stop signal."); break
        logger.info(f"Mass schedule complete: {scheduled} scans queued, {skipped} skipped.")

    def cancel_pending_scans(self, address: str) -> int:
        """Elimina trabajos pendientes para un target específico de la cola."""
        if not self.running: logger.warning(f"Cannot cancel scans for {address}: loop not running."); return 0
        cancelled_count = 0
        temp_queue = queue.Queue()
        # Vaciar cola original a una temporal, omitiendo los cancelados
        while not self.scan_jobs.empty():
            try:
                job_dest, job_opts = self.scan_jobs.get_nowait()
                if job_dest == address:
                    cancelled_count += 1
                    try: self.scan_jobs.task_done() # Marcar como hecho para join()
                    except ValueError: pass # Ignorar si ya se hizo
                    logger.debug(f"Cancelling pending job for {address}")
                else:
                    temp_queue.put((job_dest, job_opts)) # Mantener este job
            except queue.Empty: break
            except Exception as e: logger.error(f"Error processing job queue during cancel: {e}") # Evitar loop infinito; break
        # Reemplazar la cola original (thread-safe? queue no tiene método replace)
        # Bloquear acceso a la cola mientras se reemplaza podría ser necesario en sistemas muy cargados.
        # Para simplificar, asumimos que no hay escrituras concurrentes durante este breve instante.
        self.scan_jobs = temp_queue
        logger.info(f"Cancelled {cancelled_count} pending jobs for {address}. New queue size: {self.scan_jobs.qsize()}")
        return cancelled_count

EOF

# ./core/storage.py
cat << 'EOF' > "$INSTALL_DIR/core/storage.py"
#!/usr/bin/env python3
"""
Módulo de almacenamiento para mtr-topology.
Gestiona InfluxDB y agentes JSON.
"""
import logging, json, time, os, threading
from typing import List, Dict, Any, Optional, Union, TYPE_CHECKING
from influxdb import InfluxDBClient
from influxdb.exceptions import InfluxDBClientError, InfluxDBServerError
from datetime import datetime, timedelta, timezone # <-- timezone importado
import dateutil.parser

if TYPE_CHECKING:
    from .mtr import MTRResult, HopResult # <-- Uso de TYPE_CHECKING

logger = logging.getLogger(__name__)

class StorageError(Exception): pass
class InfluxConnectionError(StorageError): pass
class AgentFileError(StorageError): pass

class InfluxStorage:
    """Almacenamiento InfluxDB y gestión de agentes JSON."""
    def __init__(
        self, host: str='localhost', port: int=8086, username: Optional[str]=None, password: Optional[str]=None,
        database: str='mtr_topology', agents_file: str='agents.json', ssl: bool=False, verify_ssl: bool=False,
        retention_policy: Optional[str]=None, default_tags: Optional[Dict[str, str]]=None, influx_timeout: int=10
    ):
        self.influx_host=host; self.influx_port=port; self.influx_username=username; self.influx_password=password;
        self.influx_database=database; self.influx_ssl=ssl; self.influx_verify_ssl=verify_ssl;
        self.influx_retention_policy=retention_policy; self.influx_default_tags=default_tags or {};
        self.influx_timeout=influx_timeout; self.influx_client:Optional[InfluxDBClient]=None;
        self._influx_lock = threading.RLock()
        self.agents_file_path = agents_file; self._agents_data:Dict[str,Dict[str,Any]]={};
        self._agents_lock = threading.RLock()
        try:
            self._load_agents_from_file()
        except AgentFileError as e:
            logger.error(f"Error cargando agentes: {e}. Iniciando con lista vacía.")
            self._agents_data={} # Asegurar lista vacía
            # Intentar crear archivo vacío si no existe
            if not os.path.exists(self.agents_file_path):
                try: self._save_agents_to_file()
                except Exception as save_e: logger.error(f"No se pudo crear archivo de agentes inicial: {save_e}")
        except Exception as e:
            logger.error(f"Error inesperado cargando agentes: {e}", exc_info=True); self._agents_data={}
        try:
            self._connect_influxdb()
        except InfluxConnectionError as e:
            logger.error(f"Error inicial conectando InfluxDB: {e}. Se reintentará en las operaciones.")
        except Exception as e:
            logger.error(f"Error inesperado conectando InfluxDB: {e}", exc_info=True)


    def _connect_influxdb(self):
        # Ya se asume el lock externo
        if self.influx_client:
             try: self.influx_client.ping(); logger.debug("Ping InfluxDB OK."); return
             except Exception: logger.warning("Ping InfluxDB falló, reconectando..."); self.influx_client=None

        logger.info(f"Conectando a InfluxDB {self.influx_host}:{self.influx_port}...")
        try:
            self.influx_client=InfluxDBClient(host=self.influx_host,port=self.influx_port,username=self.influx_username,password=self.influx_password,database=self.influx_database,ssl=self.influx_ssl,verify_ssl=self.influx_verify_ssl,timeout=self.influx_timeout)
            # Verificar conexión ANTES de chequear/crear DB
            self.influx_client.ping()
            logger.info("Ping inicial a InfluxDB exitoso.")
            databases=self.influx_client.get_list_database()
            if {'name':self.influx_database} not in databases:
                logger.warning(f"DB '{self.influx_database}' no existe, creándola..."); self.influx_client.create_database(self.influx_database)
            # No es necesario switch_database si se especificó en el constructor
            logger.info(f"Conectado y listo para usar InfluxDB (DB: {self.influx_database})")
        except InfluxDBClientError as e: # Error cliente (auth, etc)
            self.influx_client=None; raise InfluxConnectionError(f"Error cliente InfluxDB: {e}") from e
        except InfluxDBServerError as e: # Error servidor (inaccesible, etc)
            self.influx_client=None; raise InfluxConnectionError(f"Error servidor InfluxDB: {e}") from e
        except Exception as e: # Otro error (requests, etc)
            self.influx_client=None; raise InfluxConnectionError(f"Fallo conexión InfluxDB genérico: {e}") from e

    def _ensure_influx_connection(self):
        # Ya se asume el lock externo
        if not self.influx_client: self._connect_influxdb()
        else:
            try: self.influx_client.ping()
            except Exception: logger.warning("Conexión InfluxDB perdida, reconectando..."); self._connect_influxdb()

    def close(self): # <-- Método close implementado
        with self._influx_lock:
            if self.influx_client:
                try: self.influx_client.close(); logger.info("Conexión InfluxDB cerrada.")
                except Exception as e: logger.warning(f"Error cerrando conexión InfluxDB: {e}")
                finally: self.influx_client = None

    def store_mtr_result(self, mtr_result: "MTRResult") -> bool:
        points = []
        try:
            points = self._convert_mtr_to_points(mtr_result)
            if not points:
                logger.debug(f"No se generaron puntos para MTR {mtr_result.destination}, status {mtr_result.status}")
                return True # No es un error si no hay puntos (ej. fallo antes del primer hop)

            with self._influx_lock:
                 self._ensure_influx_connection()
                 # Usar batching si write_points lo soporta (la librería lo hace internamente)
                 write_success = self.influx_client.write_points(points, time_precision='ms', retention_policy=self.influx_retention_policy)
                 if write_success: logger.debug(f"Almacenados {len(points)} puntos MTR para {mtr_result.destination}"); return True
                 else: logger.error(f"Fallo write_points InfluxDB para {mtr_result.destination}"); return False
        except InfluxConnectionError as e: logger.error(f"Error conexión InfluxDB guardando MTR {mtr_result.destination}: {e}"); return False
        except Exception as e: logger.error(f"Error inesperado guardando MTR {mtr_result.destination}: {e}", exc_info=True); return False

    def _convert_mtr_to_points(self, mtr_result: "MTRResult") -> List[Dict[str, Any]]:
        points = []
        # Usar UTC si no hay end_time
        ts_dt = datetime.fromtimestamp(mtr_result.end_time, tz=timezone.utc) if mtr_result.end_time else datetime.now(timezone.utc)
        ts_iso = ts_dt.isoformat() # Formato preferido por InfluxDB

        # Obtener info del agente DESPUÉS de bloquear, por si se actualiza
        with self._agents_lock: agent_info = self._agents_data.get(mtr_result.destination)
        agent_tags={'group': agent_info.get('group','default') if agent_info else 'unknown'}
        dest_name=agent_info.get('name', mtr_result.destination) if agent_info else mtr_result.destination

        path_signature = self._calculate_path_signature(mtr_result.hops)
        common_tags = {'source':mtr_result.source, 'destination':mtr_result.destination, 'destination_name':dest_name, 'path_signature':path_signature, **agent_tags, **self.influx_default_tags}

        # 1. Punto mtr_scan (Siempre presente, indica que se intentó)
        scan_flds={'duration_ms': int(mtr_result.duration*1000) if mtr_result.duration else None,'total_hops': len(mtr_result.hops),'completed': mtr_result.status=='completed','error': mtr_result.error or ''}
        scan_flds={k:v for k,v in scan_flds.items() if v is not None and v!=''} # Limpiar nulos/vacíos
        points.append({'measurement':'mtr_scan', 'tags':{**common_tags,'status':mtr_result.status}, 'time':ts_iso, 'fields':scan_flds or {'dummy':1}}) # Añadir dummy si no hay fields

        # Solo añadir path y hops si el MTR no falló catastróficamente (ej. resolve error, permission error)
        if mtr_result.status not in ["error", "permission_error"] and mtr_result.hops:
            # 2. Punto mtr_path
            valid_hops = [h for h in mtr_result.hops if h.ip_address]; path_ips=[h.ip_address for h in valid_hops]
            if path_ips: points.append({'measurement':'mtr_path', 'tags':common_tags, 'time':ts_iso, 'fields':{'path_json':json.dumps(path_ips), 'hop_count':len(path_ips)}})

            # 3. Puntos mtr_hop
            for hop in valid_hops:
                # Incluir latencias solo si hay pings exitosos
                latency_fields = {}
                if hop.successful_pings:
                    latency_fields = { 'avg_latency':hop.avg_latency, 'min_latency':hop.min_latency, 'max_latency':hop.max_latency }

                hop_flds={
                    'packet_loss':hop.packet_loss, 'sent_count':hop.sent_count, 'received_count':hop.received_count,
                    'response_types':json.dumps(hop.response_types_summary),
                    **latency_fields
                }
                hop_flds={k:v for k,v in hop_flds.items() if v is not None} # Limpiar nulos
                if hop_flds: points.append({'measurement':'mtr_hop', 'tags':{**common_tags, 'hop_number':hop.hop_number, 'hop_ip':hop.ip_address, 'is_destination':str(hop.ip_address==mtr_result.destination).lower()}, 'time':ts_iso, 'fields':hop_flds}) # is_destination como string

        return points

    def _calculate_path_signature(self, hops: List["HopResult"]) -> str:
        path_ips=[h.ip_address for h in hops if h.ip_address]; return "_".join(path_ips) if path_ips else "empty_path"

    def query_influxdb(self, query: str, database: Optional[str]=None) -> Optional[Any]:
        """Ejecuta una query en InfluxDB asegurando conexión."""
        try:
            with self._influx_lock:
                 self._ensure_influx_connection()
                 db=database or self.influx_database
                 logger.debug(f"Ejecutando InfluxDB query en '{db}': {query[:200]}...")
                 # Usar epoch='ms' para obtener timestamps numéricos consistentes
                 result = self.influx_client.query(query, database=db, epoch='ms')
                 return result
        except InfluxConnectionError as e: logger.error(f"Error conexión InfluxDB query: {e}"); return None
        except InfluxDBClientError as e: logger.error(f"Error cliente InfluxDB query: {e}"); return None
        except InfluxDBServerError as e: logger.error(f"Error servidor InfluxDB query: {e}"); return None
        except Exception as e: logger.error(f"Error inesperado query InfluxDB: {e}", exc_info=True); return None

    def query_topology(self, time_range: str='1h', group: Optional[str]=None, agent: Optional[str]=None) -> Dict[str, List]:
        """Obtiene datos de topología desde InfluxDB."""
        default_result = {'nodes': [], 'links': []}
        try:
            # 1. Obtener las rutas más recientes para los agentes filtrados
            where_clauses = [f"time > now() - {time_range}"]
            if group and group != 'all': where_clauses.append(f"\"group\" = '{group}'")
            if agent and agent != 'all': where_clauses.append(f"\"destination\" = '{agent}'")
            where_str = " AND ".join(where_clauses)

            query_paths = f"""SELECT last("path_json") as "path_json", "source", "group", "destination" FROM "mtr_path" WHERE {where_str} GROUP BY "source", "destination" """
            result_paths = self.query_influxdb(query_paths)
            if result_paths is None: return default_result
            points_list = list(result_paths.get_points())
            if not points_list: return default_result

            # 2. Construir nodos y enlaces iniciales
            nodes_dict = {}; links_dict = {}
            source_ip = points_list[0].get('source', 'local') # Asumir mismo source para todos
            nodes_dict["local"] = {'id': "local", 'name': "Local Server", 'ip': source_ip, 'type': "source"}
            destinations_in_topology = set()

            for point in points_list:
                path_json = point.get('path_json'); destination = point.get('destination')
                if not path_json or not destination: continue
                destinations_in_topology.add(destination)
                try: path_ips = json.loads(path_json)
                except json.JSONDecodeError: continue

                # Obtener nombre y grupo del agente desde la cache interna
                with self._agents_lock: agent_info = self._agents_data.get(destination)
                dest_name=agent_info.get('name', destination) if agent_info else destination
                node_group=agent_info.get('group', 'default') if agent_info else 'unknown'
                nodes_dict[destination] = {'id': destination, 'name': dest_name, 'ip': destination, 'type': "destination", 'group': node_group}

                prev_hop_id = "local"
                for hop_ip in path_ips:
                    if not hop_ip: continue # Saltar hops vacíos (timeouts)
                    hop_id = hop_ip # Usar IP como ID para consistencia
                    if hop_id not in nodes_dict: nodes_dict[hop_id] = {'id': hop_id, 'name': hop_ip, 'ip': hop_ip, 'type': "router"}
                    link_id = f"{prev_hop_id}--{hop_id}" # Enlace entre hop anterior y actual
                    if link_id not in links_dict: links_dict[link_id] = {'id': link_id, 'source': prev_hop_id, 'target': hop_id, 'destinations': set(), 'latency': None, 'loss': None, 'count': 0}
                    links_dict[link_id]['destinations'].add(destination)
                    prev_hop_id = hop_id

            # 3. Obtener métricas promedio para los hops involucrados
            hop_ips_in_topology = [n['id'] for n in nodes_dict.values() if n['type'] == 'router']
            hop_metrics = {}
            if hop_ips_in_topology:
                 # Formatear IPs para query
                 hop_ip_filter_parts = [f"\"hop_ip\" = '{ip}'" for ip in hop_ips_in_topology]
                 if hop_ip_filter_parts:
                     hop_ip_filter = " OR ".join(hop_ip_filter_parts)
                     # Query para obtener métricas agregadas (media) por hop_ip
                     metrics_query = f""" SELECT mean("avg_latency") as "avg_latency", mean("packet_loss") as "packet_loss" FROM "mtr_hop" WHERE {where_str} AND ({hop_ip_filter}) GROUP BY "hop_ip" """
                     metrics_result = self.query_influxdb(metrics_query)
                     if metrics_result:
                          for point in metrics_result.get_points(): hop_metrics[point['hop_ip']] = {'latency': point['avg_latency'], 'loss': point['packet_loss']}

            # 4. Asignar métricas a los enlaces
            final_links = []
            for link_data in links_dict.values():
                target_id = link_data['target'] # El target del enlace es el hop actual
                metrics = hop_metrics.get(target_id)
                if metrics: link_data['latency'] = metrics['latency']; link_data['loss'] = metrics['loss']
                # Convertir set a lista para JSON
                link_data['destinations'] = list(link_data['destinations'])
                link_data['count'] = len(link_data['destinations']) # Añadir recuento
                final_links.append(link_data)

            # 5. Filtrar nodos que no estén en ningún enlace final (excepto 'local')
            nodes_in_links = set(['local'])
            for link in final_links: nodes_in_links.add(link['source']); nodes_in_links.add(link['target'])
            final_nodes = [node for node_id, node in nodes_dict.items() if node_id in nodes_in_links]

            return {'nodes': final_nodes, 'links': final_links}
        except Exception as e: logger.error(f"Error query_topology: {e}", exc_info=True); return default_result

    def query_dashboard_metrics(self, time_range: str='24h', group: Optional[str]=None) -> Dict[str, Any]:
        """Obtiene métricas para el dashboard."""
        metrics = {"latency_timeseries": [], "loss_timeseries": [], "summary": {}}
        try:
            # Preparar filtros base
            where_clauses = [f"time > now() - {time_range}"]
            if group and group != 'all': where_clauses.append(f"\"group\" = '{group}'")
            base_where_str = " AND ".join(where_clauses)

            # Calcular intervalo de agregación basado en time_range
            interval = '1h'; # Default para > 24h
            tr_val = int(time_range[:-1]); tr_unit = time_range[-1]
            if tr_unit == 'm': interval = '1m' if tr_val <= 60 else '5m'
            elif tr_unit == 'h': interval = '1m' if tr_val <= 1 else '5m' if tr_val <= 6 else '15m' if tr_val <= 12 else '30m'
            elif tr_unit == 'd': interval = '1h' if tr_val <= 1 else '2h' if tr_val <= 7 else '6h'

            # Query para timeseries (agregado sobre *todos* los hops finales)
            ts_where_str = f"{base_where_str} AND \"is_destination\" = 'true'"
            query_ts = f""" SELECT mean("avg_latency") as "p50", max("max_latency") as "p95", mean("packet_loss") as "avg_loss" FROM "mtr_hop" WHERE {ts_where_str} GROUP BY time({interval}) fill(none) """
            result_ts = self.query_influxdb(query_ts)
            if result_ts:
                for point in result_ts.get_points():
                    # Convertir epoch ms a ISO string UTC
                    ts_iso = datetime.fromtimestamp(point['time']/1000, tz=timezone.utc).isoformat()
                    lat_p50 = point.get('p50'); lat_p95 = point.get('p95'); loss_avg = point.get('avg_loss')
                    if lat_p50 is not None: metrics["latency_timeseries"].append({'time':ts_iso, 'p50':lat_p50, 'p95':lat_p95})
                    if loss_avg is not None: metrics["loss_timeseries"].append({'time':ts_iso, 'avg_loss':loss_avg})

            # Query Summary (promedios generales del rango completo y agentes con problemas recientes)
            query_overall = f""" SELECT mean("avg_latency") as "avg_latency", mean("packet_loss") as "avg_loss" FROM "mtr_hop" WHERE {ts_where_str} """ # Mismo filtro que timeseries, pero sin GROUP BY time
            res_overall = self.query_influxdb(query_overall)
            point_overall = list(res_overall.get_points())[0] if res_overall else {}
            metrics["summary"]["avg_latency_overall"] = point_overall.get('avg_latency')
            metrics["summary"]["avg_loss_overall"] = point_overall.get('avg_loss')

            # Query para agentes con problemas (ej. >5% loss O >100ms avg latency en la última hora)
            prob_where_clauses = [f"time > now() - 1h", "(\"packet_loss\" > 5 OR \"avg_latency\" > 100)", "\"is_destination\" = 'true'"]
            if group and group != 'all': prob_where_clauses.append(f"\"group\" = '{group}'")
            query_problems = f""" SELECT count(distinct("destination")) as "problem_count" FROM "mtr_hop" WHERE {' AND '.join(prob_where_clauses)} """
            res_problems = self.query_influxdb(query_problems)
            point_problems = list(res_problems.get_points())[0] if res_problems else {}
            metrics["summary"]["problem_agents"] = point_problems.get('problem_count', 0)

        except Exception as e: logger.error(f"Error query_dashboard_metrics: {e}", exc_info=True)
        return metrics

    def query_path_changes(self, source: str, destination: str, time_range: str='7d') -> List[Dict[str, Any]]:
        """Obtiene los cambios de ruta para un par source-destination específico."""
        changes = []
        try:
             # Obtener segmentos de ruta distintos ordenados por tiempo
             query = f""" SELECT "path_signature", first("path_json") as "first_path", min(time) as "first_seen", max(time) as "last_seen" FROM "mtr_path" WHERE time > now() - {time_range} AND "source" = '{source}' AND "destination" = '{destination}' GROUP BY "path_signature" ORDER BY time ASC """
             result = self.query_influxdb(query)
             if not result: return changes

             path_segments = []
             for point in result.get_points():
                  # Convertir epoch ms a datetime UTC y luego a ISO string
                  first_seen_dt = datetime.fromtimestamp(point['first_seen']/1000, tz=timezone.utc)
                  last_seen_dt = datetime.fromtimestamp(point['last_seen']/1000, tz=timezone.utc)
                  duration = (last_seen_dt - first_seen_dt).total_seconds()
                  path_segments.append({
                      'path_signature': point['path_signature'],
                      'first_seen': first_seen_dt.isoformat(),
                      'last_seen': last_seen_dt.isoformat(),
                      'duration_seconds': duration,
                      'path': json.loads(point.get('first_path', '[]')) # Cargar path
                  })

             # Comparar segmentos consecutivos para detectar cambios
             for i in range(1, len(path_segments)):
                  prev, curr = path_segments[i-1], path_segments[i]
                  # El cambio ocurre cuando empieza el segmento actual
                  changes.append({
                       'change_time': curr['first_seen'], # Tiempo del cambio
                       'source': source, 'destination': destination, # Añadir info
                       'old_path': prev['path'], 'new_path': curr['path'],
                       'old_signature': prev['path_signature'], 'new_signature': curr['path_signature'],
                       'previous_duration_str': self._format_duration(prev['duration_seconds']) # Duración de la ruta anterior
                  })
             return changes
        except Exception as e: logger.error(f"Error query_path_changes {source}->{destination}: {e}", exc_info=True); return []

    def query_recent_path_changes(self, time_range: str = '7d', group: Optional[str] = None, limit: int = 10) -> List[Dict[str, Any]]:
        """Obtiene los N cambios de ruta más recientes para todos los agentes o un grupo."""
        all_changes = []
        try:
            # 1. Obtener todos los pares source-destination activos recientes filtrados por grupo si aplica
            where_clauses_sd = [f"time > now() - {time_range}"]
            if group and group != 'all': where_clauses_sd.append(f"\"group\" = '{group}'")
            # Query para obtener pares únicos (source, destination)
            query_sd = f""" SELECT DISTINCT("destination") FROM "mtr_path" WHERE {' AND '.join(where_clauses_sd)} GROUP BY "source" """
            result_sd = self.query_influxdb(query_sd)
            if not result_sd: return []

            # Usar get_points() para obtener los pares (source está en las tags)
            pairs_to_check = []
            for series, points in result_sd.items():
                source = series[1][1] # ('mtr_path', ('source', 'xxx'))
                for point in points:
                    destination = point.get('distinct')
                    if source and destination: pairs_to_check.append((source, destination))

            logger.debug(f"Checking path changes for {len(pairs_to_check)} source-destination pairs.")

            # 2. Para cada par, obtener sus cambios
            change_futures = []
            # Usar un ThreadPool podría acelerar esto si hay muchos pares y la query es lenta
            # executor = ThreadPoolExecutor(max_workers=5)
            for source, destination in pairs_to_check:
                # future = executor.submit(self.query_path_changes, source, destination, time_range)
                # change_futures.append(future)
                 pair_changes = self.query_path_changes(source, destination, time_range)
                 all_changes.extend(pair_changes) # Ejecución secuencial por ahora

            # Recolectar resultados si se usan futures
            # for future in as_completed(change_futures):
            #     try: all_changes.extend(future.result())
            #     except Exception as e: logger.error(f"Error getting path changes result: {e}")
            # executor.shutdown()

            # 3. Ordenar todos los cambios por tiempo (más reciente primero) y limitar
            all_changes.sort(key=lambda x: x.get('change_time', ''), reverse=True)
            logger.info(f"Found {len(all_changes)} total path changes, returning top {limit}.")
            return all_changes[:limit]

        except Exception as e:
            logger.error(f"Error query_recent_path_changes: {e}", exc_info=True)
            return []


    def _format_duration(self, seconds: Optional[float]) -> str:
        """Formatea duración en segundos a string legible."""
        if seconds is None or seconds < 0: return "N/A"
        if seconds<60: return f"{seconds:.0f}s"
        mins, secs = divmod(seconds, 60)
        if mins<60: return f"{mins:.0f}m {secs:.0f}s"
        hrs, mins = divmod(mins, 60)
        if hrs<24: return f"{hrs:.0f}h {mins:.0f}m"
        days, hrs = divmod(hrs, 24)
        return f"{days:.0f}d {hrs:.0f}h"

    # --- Métodos Agentes (Archivo JSON) ---
    def _load_agents_from_file(self): # Protección contra JSON malformado y concurrencia
        with self._agents_lock:
            self._agents_data = {} # Empezar vacío
            if not os.path.exists(self.agents_file_path):
                 logger.warning(f"Archivo agentes '{self.agents_file_path}' no existe. Se creará vacío."); return # No lanzar error, solo advertir
            try:
                with open(self.agents_file_path, 'r') as f: data = json.load(f)
                if not isinstance(data, dict) or "agents" not in data or not isinstance(data["agents"], list):
                     raise AgentFileError("Formato JSON inválido: falta clave 'agents' (lista).")
                for agent_dict in data["agents"]:
                    addr = agent_dict.get("address")
                    if not addr: logger.warning(f"Agente omitido (sin 'address'): {agent_dict}"); continue
                    # Validar/Defaults
                    agent_dict.setdefault('name', addr); agent_dict.setdefault('group', 'default'); agent_dict.setdefault('enabled', True); agent_dict.setdefault('options', {})
                    if not isinstance(agent_dict['enabled'], bool): agent_dict['enabled']=True
                    if not isinstance(agent_dict['options'], dict): agent_dict['options']={}
                    self._agents_data[addr] = agent_dict
                logger.info(f"Cargados {len(self._agents_data)} agentes desde '{self.agents_file_path}'")
            except json.JSONDecodeError as e: raise AgentFileError(f"Error formato JSON en {self.agents_file_path}: {e}") from e
            except Exception as e: logger.error(f"Error leyendo agentes: {e}", exc_info=True); self._agents_data={} # Resetear si falla

    def _save_agents_to_file(self) -> bool:
        # Ya se asume el lock externo
        try:
            # Crear directorio si no existe (necesario si es el primer guardado y el path no es solo el nombre)
            agents_dir = os.path.dirname(self.agents_file_path)
            if agents_dir: os.makedirs(agents_dir, exist_ok=True)

            data_to_save = {"agents": list(self._agents_data.values())}
            # Escribir en archivo temporal y renombrar para atomicidad
            temp_path = self.agents_file_path + ".tmp"
            with open(temp_path, 'w') as f: json.dump(data_to_save, f, indent=2)
            os.replace(temp_path, self.agents_file_path) # Renombrado atómico (si es posible)
            logger.info(f"Guardados {len(self._agents_data)} agentes en '{self.agents_file_path}'")
            return True
        except Exception as e: logger.error(f"Error guardando agentes en '{self.agents_file_path}': {e}", exc_info=True); return False

    def get_agents(self, enabled_only: bool=False, group: Optional[str]=None) -> List[Dict[str, Any]]:
        """Obtiene agentes, filtrando opcionalmente."""
        with self._agents_lock:
             # Crear una copia profunda para evitar modificar la caché interna accidentalmente
             all_agents = [dict(a) for a in self._agents_data.values()]
        if enabled_only: all_agents = [a for a in all_agents if a.get('enabled', True)]
        if group and group != 'all': all_agents = [a for a in all_agents if a.get('group', 'default') == group]
        return all_agents

    def get_agent(self, address: str) -> Optional[Dict[str, Any]]:
        """Obtiene un agente específico por dirección."""
        with self._agents_lock:
             agent = self._agents_data.get(address)
             # Devolver una copia para seguridad
             return dict(agent) if agent else None

    def get_groups(self) -> List[str]:
        """Obtiene la lista de grupos únicos."""
        with self._agents_lock: groups = set(a.get('group', 'default') for a in self._agents_data.values())
        return sorted([g for g in groups if g]) # Excluir None/vacío y ordenar

    def add_agent(self, address:str, name:Optional[str]=None, group:Optional[str]=None, enabled:bool=True, options:Optional[Dict]=None) -> bool:
        """Añade o actualiza un agente."""
        with self._agents_lock:
            is_update = address in self._agents_data
            # Limpiar y validar datos
            clean_addr = address.strip()
            clean_name = (name or clean_addr).strip()
            clean_group = (group or 'default').strip()
            clean_options = options or {}
            if not clean_addr:
                 logger.error("Intento de añadir agente sin dirección."); return False

            self._agents_data[clean_addr] = {"address":clean_addr, "name":clean_name, "group":clean_group, "enabled":bool(enabled), "options":clean_options}
            saved = self._save_agents_to_file()
            if saved: logger.info(f"Agente {'actualizado' if is_update else 'añadido'}: {clean_addr}")
            return saved

    def remove_agent(self, address: str) -> bool:
        """Elimina un agente."""
        with self._agents_lock:
            if address in self._agents_data:
                del self._agents_data[address]; saved=self._save_agents_to_file()
                if saved: logger.info(f"Agente eliminado: {address}")
                return saved
            else: logger.warning(f"Intento eliminar agente inexistente: {address}"); return False

    def update_agent_status(self, address: str, enabled: bool) -> bool:
        """Actualiza el estado 'enabled' de un agente."""
        with self._agents_lock:
            agent = self._agents_data.get(address)
            if agent:
                agent['enabled'] = bool(enabled); saved=self._save_agents_to_file()
                if saved: logger.info(f"Estado agente {address} -> {'enabled' if enabled else 'disabled'}")
                return saved
            else: logger.warning(f"Intento actualizar estado agente inexistente: {address}"); return False
EOF

# ./main.py
cat << 'EOF' > "$INSTALL_DIR/main.py"
#!/usr/bin/env python3
"""
Punto de entrada principal para mtr-topology.
"""
import os, sys, time, logging, threading, signal
from typing import Dict, Any, List, Optional

# --- Imports Corregidos ---
from config import config, load_from_args
from core.storage import InfluxStorage, StorageError, AgentFileError, InfluxConnectionError # Tipos de error importados
from core.mtr import MTRRunner # MTRResult no se usa aquí directamente
# Importar web app y funciones de inicio/parada
try:
    from web.app import app as flask_app, init_flask_app, shutdown_flask_app
    WEB_AVAILABLE = True
except ImportError as e:
    print(f"WARN: No se pudo importar 'web.app' ({e}). El servidor web no estará disponible.", file=sys.stderr)
    WEB_AVAILABLE = False
    flask_app = None
    def init_flask_app(*args, **kwargs): pass
    def shutdown_flask_app(*args, **kwargs): pass
# --- Fin Imports ---

logger = logging.getLogger("main") # Usar nombre específico

class MTRTopologyService:
    """Orquesta el servicio MTR Topology."""
    def __init__(self):
        self.storage: Optional[InfluxStorage] = None
        self.mtr_runner: Optional[MTRRunner] = None
        self.web_app = flask_app # Puede ser None
        self.scheduler_thread: Optional[threading.Thread] = None
        self.stop_event = threading.Event()
        self._running = False
        self._initialized = False

    def initialize(self) -> bool:
        """Inicializa todos los componentes del servicio."""
        if self._initialized:
            logger.warning("Servicio ya inicializado.")
            return True

        logger.info("Inicializando MTR Topology Service...")
        try:
            # 1. Storage (con captura de AgentFileError)
            storage_config = config.get('storage', {})
            agents_file_path = storage_config.get('agents_file')
            if not agents_file_path:
                 logger.critical("Configuración 'storage.agents_file' no definida. Abortando.")
                 return False

            try:
                self.storage = InfluxStorage(
                    host=storage_config.get('host','localhost'), port=storage_config.get('port',8086),
                    username=storage_config.get('username'), password=storage_config.get('password'),
                    database=storage_config.get('database','mtr_topology'), agents_file=agents_file_path,
                    ssl=storage_config.get('ssl',False), verify_ssl=storage_config.get('verify_ssl',False),
                    default_tags=storage_config.get('default_tags',{}), influx_timeout=storage_config.get('influx_timeout',10)
                )
            except AgentFileError as e:
                 logger.critical(f"Error crítico cargando archivo agentes: {e}. Abortando.")
                 return False
            # Permitir continuar si Influx falla al inicio, pero loguear error
            except InfluxConnectionError as e:
                 logger.error(f"Error inicial conectando InfluxDB: {e}. Funcionalidad de almacenamiento Influx limitada.")

            # Cargar agentes DESPUÉS de inicializar storage
            initial_agents = self.storage.get_agents()
            logger.info(f"Cargados {len(initial_agents)} agentes desde config.")

            # 2. MTR Runner
            self.mtr_runner = MTRRunner(storage=self.storage)
            self.mtr_runner.set_options(config.get('mtr', {}))
            # Añadir targets iniciales activos al runner
            activated_count = 0
            for agent in initial_agents:
                 if agent.get('enabled', True):
                     self.mtr_runner.add_target(agent['address'])
                     activated_count += 1
            logger.info(f"Activados {activated_count} targets en MTR Runner.")


            # 3. Flask App (si está disponible)
            if WEB_AVAILABLE and self.web_app:
                flask_config = {
                    'storage': self.storage,
                    'mtr_runner': self.mtr_runner,
                    'config': config,
                    'agents_lock': self.storage._agents_lock # Pasar el lock
                 }
                init_flask_app(flask_config)
            else:
                logger.warning("Web UI/API no disponible (importación falló).")

            self._initialized = True
            logger.info("Servicio inicializado correctamente.")
            return True

        except StorageError as e:
             logger.error(f"Error almacenamiento durante inicialización: {e}", exc_info=True); return False
        except Exception as e:
            logger.error(f"Error inesperado inicialización: {e}", exc_info=True); return False

    def _scheduler_loop(self):
        """Bucle del programador de escaneos."""
        scan_interval = config.get('scan.scan_interval', 300)
        if scan_interval <= 0:
             logger.warning("Programador de escaneos deshabilitado (scan_interval <= 0).")
             return

        logger.info(f"Programador de escaneos iniciado (intervalo: {scan_interval}s)")

        if config.get('scan.scan_on_start', True):
             logger.info("Ejecutando escaneo inicial programado...")
             self._run_scheduled_scan()

        while not self.stop_event.wait(scan_interval): # wait() es eficiente y responde al evento
            logger.debug("Ejecutando escaneo programado...")
            try:
                self._run_scheduled_scan()
            except Exception as e:
                 # Evitar que un error en el escaneo detenga el scheduler
                 logger.error(f"Error en ciclo del programador: {e}", exc_info=True)
                 time.sleep(30) # Esperar un poco antes de reintentar

        logger.info("Programador de escaneos detenido.")

    def _run_scheduled_scan(self):
         """Lógica para ejecutar un escaneo programado."""
         if not self.mtr_runner or not self.storage:
              logger.warning("Intento de escaneo programado sin runner o storage inicializado.")
              return
         try:
             # Obtener agentes habilitados directamente desde storage
             enabled_agents = self.storage.get_agents(enabled_only=True)
             if enabled_agents:
                 logger.info(f"Programador: Encolando escaneo para {len(enabled_agents)} agentes habilitados...")
                 self.mtr_runner.schedule_scan_all(enabled_agents, randomize_interval=True)
             else:
                 logger.info("Programador: No hay agentes habilitados para escanear.")
         except Exception as e:
             logger.error(f"Error durante ejecución de escaneo programado: {e}", exc_info=True)

    def start(self):
        """Inicia el servicio principal y el servidor web."""
        if self._running:
            logger.warning("Servicio ya está corriendo."); return
        if not self._initialized:
            logger.error("Servicio no inicializado. Llama a initialize() primero.")
            return

        logger.info("Iniciando MTR Topology Service...")
        self._running = True; self.stop_event.clear()

        # Iniciar MTR Runner (workers)
        self.mtr_runner.start_scan_loop(config.get('mtr.parallel_jobs', 10))

        # Iniciar Scheduler si el intervalo es > 0
        scan_interval = config.get('scan.scan_interval', 300)
        if scan_interval > 0:
            self.scheduler_thread = threading.Thread(target=self._scheduler_loop, daemon=True, name="SchedulerThread"); self.scheduler_thread.start()

        # Iniciar Flask App (si está disponible)
        if WEB_AVAILABLE and self.web_app:
            web_host=config.get('web.host','0.0.0.0'); web_port=config.get('web.port',5000); web_debug=config.get('web.debug',False)
            logger.info(f"Iniciando Web UI/API en http://{web_host}:{web_port} (Debug: {web_debug})")
            try:
                 # Ejecutar Flask (bloqueante si debug=True, usar threaded=True si no debug)
                 self.web_app.run(host=web_host, port=web_port, debug=web_debug, use_reloader=False, threaded=not web_debug)
                 # Si run() retorna (p.ej. con Ctrl+C en modo debug), iniciar parada
                 logger.info("Servidor Flask terminado.")
                 if self._running: self.stop()
            except Exception as e:
                 logger.error(f"Error crítico iniciando Flask: {e}", exc_info=True)
                 self.stop() # Intentar detener todo si Flask falla
        else:
            logger.info("Web UI/API no iniciada. El servicio correrá solo como backend.")
            # Mantener el script vivo si no hay Flask
            while not self.stop_event.is_set():
                 self.stop_event.wait(timeout=60) # Esperar indefinidamente revisando stop_event
            logger.info("Recibida señal de parada (modo backend).")
            if self._running: self.stop() # Asegurar limpieza

    def stop(self):
        """Detiene todos los componentes del servicio de forma ordenada."""
        if not self._running and not self.stop_event.is_set():
             logger.warning("Servicio no activo o ya en proceso de parada."); return
        if self.stop_event.is_set():
             logger.info("Proceso de parada ya iniciado."); return # Evitar llamadas múltiples

        logger.info("Deteniendo MTR Topology Service...")
        self._running = False; self.stop_event.set() # Señalizar parada PRIMERO

        # Detener Scheduler
        if self.scheduler_thread and self.scheduler_thread.is_alive():
             logger.info("Deteniendo programador..."); self.scheduler_thread.join(timeout=5.0)
             if self.scheduler_thread.is_alive(): logger.warning("Programador no finalizó a tiempo.")

        # Detener MTR Runner (después del scheduler para que no programe más)
        if self.mtr_runner:
             logger.info("Deteniendo MTR runner..."); self.mtr_runner.stop_scan_loop(wait=True) # Esperar a workers

        # Detener Flask (si existe)
        if WEB_AVAILABLE and self.web_app:
             logger.info("Realizando limpieza Flask..."); shutdown_flask_app()

        # Cerrar Storage
        if self.storage:
             logger.info("Cerrando almacenamiento..."); self.storage.close()

        self._initialized = False # Marcar como no inicializado
        logger.info("Servicio MTR Topology detenido completamente.")

# --- Manejo Señales y Ejecución ---
service_instance: Optional[MTRTopologyService] = None
def handle_signal(signum, frame):
    """Manejador de señales SIGINT y SIGTERM."""
    signal_name = signal.Signals(signum).name
    logger.warning(f"Recibida señal {signal_name}. Iniciando cierre ordenado...")
    global service_instance
    if service_instance and not service_instance.stop_event.is_set():
        # Ejecutar stop en un hilo separado para no bloquear el manejador de señales
        threading.Thread(target=service_instance.stop, name="ShutdownThread").start()
    elif not service_instance:
        print("Servicio no instanciado, saliendo directamente.")
        sys.exit(0)
    else:
        logger.info("Cierre ya en progreso.")

if __name__ == "__main__":
    instance_lock_file = "/tmp/mtr_topology_instance.lock"
    lock_file_handle = None

    try:
        # Intento de bloqueo de archivo para instancia única (simple)
        lock_file_handle = os.open(instance_lock_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(lock_file_handle, str(os.getpid()).encode())
        print(f"Lock de instancia adquirido ({instance_lock_file})")

        # Cargar configuración y configurar logging
        try: load_from_args()
        except Exception as e: print(f"Error fatal cargando config: {e}", file=sys.stderr); sys.exit(1)

        # Registrar manejadores de señales
        signal.signal(signal.SIGINT, handle_signal); signal.signal(signal.SIGTERM, handle_signal)

        # Crear e inicializar servicio
        service_instance = MTRTopologyService()
        if not service_instance.initialize():
             logger.critical("Fallo inicialización del servicio. Abortando."); sys.exit(1)

        # Iniciar servicio (bloquea si Flask está activo, o espera a stop_event)
        service_instance.start()

    except FileExistsError:
        print(f"ERROR: Otra instancia parece estar corriendo (lock file '{instance_lock_file}' existe).", file=sys.stderr)
        # Leer PID del lock file si es posible
        try:
            with open(instance_lock_file, 'r') as f: pid = f.read().strip()
            print(f"PID en lock file: {pid}", file=sys.stderr)
        except Exception: pass
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("KeyboardInterrupt capturado en main. Deteniendo servicio...")
        if service_instance: service_instance.stop()
    except Exception as e:
        logger.critical(f"Error fatal en ejecución principal: {e}", exc_info=True)
        if service_instance: service_instance.stop()
        sys.exit(1)
    finally:
        # Liberar el lock al salir
        if lock_file_handle:
            try:
                os.close(lock_file_handle)
                os.remove(instance_lock_file)
                print(f"Lock de instancia liberado ({instance_lock_file})")
            except Exception as e:
                print(f"WARN: No se pudo liberar/eliminar lock file: {e}", file=sys.stderr)

    logger.info("Salida limpia del script principal.")
    sys.exit(0)
EOF

# ./requirements.txt
cat << 'EOF' > "$REQUIREMENTS_FILE"
Flask>=2.0,<3.0
influxdb>=5.3.1,<6.0
requests>=2.26.0
python-dateutil>=2.8.2
typing-extensions>=4.0.0
# Werkzeug y Jinja2 son dependencias de Flask
EOF

print_message "Archivos Python del backend creados."

# --- 5. Crear Entorno Virtual e Instalar Dependencias ---
print_message "Creando entorno virtual Python en $VENV_DIR..."
$PYTHON_CMD -m venv "$VENV_DIR" || { print_error "Fallo al crear venv."; exit 1; }
print_message "Entorno virtual creado."
print_message "Instalando dependencias desde $REQUIREMENTS_FILE..."
# Asegurar que pip en venv esté actualizado
"$VENV_DIR/bin/pip" install --upgrade pip || print_warning "Fallo al actualizar pip en venv."
"$VENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE" || { print_error "Fallo al instalar dependencias Python."; exit 1; }
print_message "Dependencias Python instaladas."

# --- 6. Crear Archivo de Servicio Systemd ---
print_message "Creando archivo de servicio systemd $SERVICE_FILE..."
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=MTR Topology Service (Backend)
After=network.target influxdb.service # Asegura que InfluxDB esté listo si es local
Documentation=file://$INSTALL_DIR/README.md # Asumiendo que habrá un README

[Service]
Type=simple
# --- Usuario dedicado y Capabilities ---
User=$APP_USER
Group=$APP_GROUP
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW
# --- Fin Usuario/Capabilities ---

WorkingDirectory=$INSTALL_DIR
# Ejecutar vía main.py usando el venv
ExecStart=$VENV_DIR/bin/python3 $INSTALL_DIR/main.py --config $CONFIG_FILE

Restart=on-failure
RestartSec=15s # Aumentar un poco el tiempo entre reinicios
TimeoutStopSec=30s # Tiempo para cierre limpio con SIGTERM

# Logging a journald
StandardOutput=journal
StandardError=journal
Environment="PYTHONUNBUFFERED=1" # Útil para logs inmediatos

# Seguridad adicional
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
# Permitir escribir solo en el archivo de agentes y en el directorio de logs
ReadWritePaths=$AGENTS_FILE $LOG_DIR
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
print_message "$SERVICE_FILE creado."

# --- 7. Establecer Permisos ---
print_message "Estableciendo permisos finales..."
chown -R "$APP_USER":"$APP_GROUP" "$INSTALL_DIR" "$LOG_DIR" || print_warning "Fallo parcial al cambiar propietario."
# Permisos para directorios (usuario/grupo: rwx, otros: ---)
find "$INSTALL_DIR" -type d -exec chmod 770 {} \;
chmod 770 "$LOG_DIR"
# Permisos para archivos (usuario/grupo: rw, otros: ---)
find "$INSTALL_DIR" -type f -exec chmod 660 {} \;
# Permisos de ejecución para script principal y venv
chmod u+x "$INSTALL_DIR/main.py"
chmod 770 "$VENV_DIR/bin/python3" # Asegurar que el usuario pueda ejecutar python
chmod 770 "$VENV_DIR/bin/pip"
# Permiso de lectura para el archivo de servicio
chmod 644 "$SERVICE_FILE"
print_message "Permisos establecidos."

# --- 8. Configurar y Habilitar Servicio ---
print_message "Configurando e iniciando el servicio systemd..."
systemctl daemon-reload || print_warning "Fallo al recargar systemd daemon."
systemctl enable "$SERVICE_NAME" || { print_error "Fallo al habilitar el servicio '$SERVICE_NAME'."; exit 1; }
systemctl restart "$SERVICE_NAME" || { print_error "Fallo al iniciar el servicio '$SERVICE_NAME'. Revisa los logs:"; journalctl -u $SERVICE_NAME -n 50 --no-pager ; exit 1; }

print_message "Esperando al servicio..."
sleep 5

# Verificar estado final del servicio
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_message "¡Backend de MTR Topology desplegado y servicio iniciado correctamente!"
    WEB_HOST=$(grep -oP '"host":\s*"\K[^"]+' "$CONFIG_FILE" || echo "0.0.0.0")
    WEB_PORT=$(grep -oP '"port":\s*\K\d+' "$CONFIG_FILE" || echo "5000")
    print_message "La API/Web (si se incluye frontend) debería estar en puerto $WEB_PORT."
    print_message "Logs: journalctl -u $SERVICE_NAME -f"
else
    print_error "El servicio '$SERVICE_NAME' no se pudo iniciar correctamente después del despliegue."
    journalctl -u $SERVICE_NAME -n 50 --no-pager
    exit 1
fi

echo -e "\n${GREEN}--- Despliegue Backend Completado ---${NC}"

exit 0
