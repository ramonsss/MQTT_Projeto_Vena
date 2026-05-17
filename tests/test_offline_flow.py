import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
from collections import deque

import paho.mqtt.client as mqtt

HOST = "127.0.0.1"
PORT = 11883
TOPIC = "cocoa/box01/telemetry"
GEN_PERIOD_S = 0.4
BUFFER_CAP = 128
DRAIN_BATCH = 4

BROKER_YAML = f"""
listeners:
  default:
    type: tcp
    bind: {HOST}:{PORT}
    max_connections: 50
sys_interval: 0
auth:
  allow-anonymous: true
topic-check:
  enabled: false
"""


def find_amqtt():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for rel in (("venv", "Scripts", "amqtt.exe"), ("venv", "bin", "amqtt")):
        p = os.path.join(here, *rel)
        if os.path.exists(p):
            return p
    return "amqtt"


def wait_port_up(host, port, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=0.5):
                return True
        except OSError:
            time.sleep(0.15)
    return False


def wait_port_down(host, port, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=0.3):
                time.sleep(0.15)
        except OSError:
            return True
    return False


class Broker:
    def __init__(self):
        self.proc = None
        self.cfg_path = None

    def start(self):
        fd, self.cfg_path = tempfile.mkstemp(prefix="amqtt_", suffix=".yaml")
        with os.fdopen(fd, "w") as f:
            f.write(BROKER_YAML)
        cmd = [find_amqtt(), "-c", self.cfg_path]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not wait_port_up(HOST, PORT, 10):
            self.stop()
            raise RuntimeError("broker nao subiu")

    def stop(self):
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
            self.proc = None
        if self.cfg_path and os.path.exists(self.cfg_path):
            os.unlink(self.cfg_path)
            self.cfg_path = None


class EspSim(threading.Thread):
    """Espelha main.cpp: ciclo gera/publica/bufferiza/drena."""

    def __init__(self):
        super().__init__(daemon=True)
        self.stop_event = threading.Event()
        self.client = mqtt.Client(client_id="cocoa-box-01-sim", clean_session=True)
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.reconnect_delay_set(min_delay=1, max_delay=4)
        self.connected = False
        self.buffer = deque(maxlen=BUFFER_CAP)
        self.generated = []   # seq na ordem de geracao
        self.published = []   # (modo, seq) na ordem em que saiu pelo publish
        self.seq = 0
        self._lock = threading.Lock()

    def _on_connect(self, c, u, f, rc):
        self.connected = (rc == 0)

    def _on_disconnect(self, c, u, rc):
        self.connected = False

    def stop(self):
        self.stop_event.set()

    def _publish(self, payload, mode):
        info = self.client.publish(TOPIC, json.dumps(payload), qos=0)
        if info.rc == mqtt.MQTT_ERR_SUCCESS:
            self.published.append((mode, payload["seq"]))
            return True
        return False

    def run(self):
        try:
            self.client.connect_async(HOST, PORT, keepalive=3)
        except Exception:
            pass
        self.client.loop_start()

        last_gen = 0.0
        try:
            while not self.stop_event.is_set():
                now = time.time()
                if now - last_gen >= GEN_PERIOD_S:
                    last_gen = now
                    self.seq += 1
                    payload = {"seq": self.seq, "ts": now}
                    self.generated.append(self.seq)

                    # Espelha main.cpp: publica direto so se conectado E buffer vazio.
                    if self.connected and not self.buffer:
                        if not self._publish(payload, "direct"):
                            self.buffer.append(payload)
                    else:
                        self.buffer.append(payload)

                # Drain: ate DRAIN_BATCH por iteracao.
                if self.connected and self.buffer:
                    for _ in range(DRAIN_BATCH):
                        if not self.buffer or not self.connected:
                            break
                        head = self.buffer[0]
                        if self._publish(head, "drain"):
                            self.buffer.popleft()
                        else:
                            break

                time.sleep(0.05)
        finally:
            self.client.loop_stop()
            try:
                self.client.disconnect()
            except Exception:
                pass


class Listener(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True)
        self.stop_event = threading.Event()
        self.client = mqtt.Client(client_id="listener", clean_session=True)
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.reconnect_delay_set(min_delay=1, max_delay=4)
        self.received = []

    def _on_connect(self, c, u, f, rc):
        if rc == 0:
            c.subscribe(TOPIC)

    def _on_message(self, c, u, msg):
        try:
            d = json.loads(msg.payload.decode("utf-8"))
            self.received.append(d["seq"])
        except Exception:
            pass

    def stop(self):
        self.stop_event.set()

    def run(self):
        try:
            self.client.connect_async(HOST, PORT, keepalive=10)
        except Exception:
            pass
        self.client.loop_start()
        self.stop_event.wait()
        self.client.loop_stop()
        try:
            self.client.disconnect()
        except Exception:
            pass


def main():
    print(f"[setup] broker em {HOST}:{PORT}")
    broker = Broker()
    broker.start()

    listener = Listener()
    listener.start()

    sim = EspSim()
    sim.start()
    time.sleep(0.8)  # da tempo de conectar

    # FASE 1: 2.5 s online
    time.sleep(2.5)
    online_direct = sum(1 for m, _ in sim.published if m == "direct")
    assert online_direct >= 3, f"esperava ao menos 3 publicacoes diretas, vi {online_direct}"
    print(f"OK [1] online: {online_direct} amostras publicadas direto (seq atual={sim.seq})")

    # FASE 2: derruba broker, simulador deve sobreviver e bufferizar
    print("[setup] derrubando broker")
    broker.stop()
    deadline = time.time() + 8
    while sim.connected and time.time() < deadline:
        time.sleep(0.1)
    assert not sim.connected, "paho nao detectou queda do broker"

    seq_before = sim.seq
    time.sleep(2.5)
    buffered = len(sim.buffer)
    new_gen = sim.seq - seq_before
    assert new_gen >= 3, f"simulador nao gerou amostras com broker offline: {new_gen}"
    assert buffered >= new_gen, f"buffer nao acumulou: gerou {new_gen}, buffer tem {buffered}"
    print(f"OK [2] offline: simulador vivo, gerou +{new_gen}, buffer={buffered}")

    # FASE 3: sobe broker, drain deve esvaziar o buffer
    print("[setup] subindo broker de novo")
    broker.start()
    deadline = time.time() + 15
    while sim.buffer and time.time() < deadline:
        time.sleep(0.2)
    assert not sim.buffer, f"buffer nao drenou: {len(sim.buffer)} restantes"
    drained = sum(1 for m, _ in sim.published if m == "drain")
    print(f"OK [3] reconectado, buffer drenado ({drained} via drain)")

    # Encerra
    time.sleep(1.0)
    sim.stop()
    sim.join(timeout=3)
    listener.stop()
    listener.join(timeout=2)
    broker.stop()

    # FASE 4: validacao FIFO
    published_seqs = [s for _, s in sim.published]
    missing = set(sim.generated) - set(published_seqs)
    assert not missing, f"amostras geradas mas nao publicadas: {sorted(missing)}"
    assert published_seqs == sorted(published_seqs), (
        f"ordem de publicacao quebrou FIFO: {published_seqs}"
    )
    print(
        f"OK [4] FIFO preservado: {len(sim.generated)} geradas, "
        f"todas publicadas em ordem"
    )

    # Listener pode ter perdido mensagens da janela offline (broker nao guarda
    # sem QoS>=1 + persistencia); reportamos so para diagnostico.
    print(
        f"\nTODOS OS TESTES PASSARAM "
        f"(geradas={len(sim.generated)}, listener recebeu={len(listener.received)})"
    )


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"\nFALHA: {e}")
        sys.exit(1)
