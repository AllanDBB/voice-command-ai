"""
Genera la matriz de confusión del KWS en dispositivo físico.

Protocolo de captura:
  1. Conectar el teléfono por USB con depuración activa
  2. Ejecutar:  adb logcat -v time *:S flutter:D | findstr KWS > mobile_log.txt
  3. Decir cada comando 10 veces en el orden de COMMANDS_ORDER,
     esperando ~2 segundos entre cada repetición y ~5 segundos entre comandos.
  4. Parar la captura (Ctrl+C) y ejecutar este script:
       python scripts/gen_mobile_confmat.py mobile_log.txt
"""

import sys
import re
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from datetime import datetime

# Orden en que se hablarán los comandos durante la prueba
COMMANDS_ORDER = ['yes', 'no', 'up', 'down', 'left', 'right', 'on', 'off', 'stop', 'go']
REPS_PER_CMD   = 10          # repeticiones por comando
SILENCE_GAP    = 3.0         # segundos de silencio entre bloques de comandos
MIN_CONF       = 0.45        # umbral mínimo de confianza (mismo que la app)

ALL_LABELS = ['yes', 'no', 'up', 'down', 'left', 'right',
              'on', 'off', 'stop', 'go', '_silence_', '_unknown_']


def parse_logcat(path: str):
    """
    Lee el archivo de logcat y extrae (timestamp, pred_label, confidence).
    Formato esperado de línea:
        MM-DD HH:MM:SS.mmm  ... I flutter: [KWS] pred=yes conf=0.923
    """
    pattern = re.compile(r'(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+).*\[KWS\] pred=(\S+) conf=([\d.]+)')
    entries = []
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = pattern.search(line)
            if m:
                ts_str, label, conf = m.group(1), m.group(2), float(m.group(3))
                ts = datetime.strptime(ts_str, '%m-%d %H:%M:%S.%f')
                if conf >= MIN_CONF:
                    entries.append((ts, label, conf))
    return entries


def segment_by_silence(entries, gap_seconds=SILENCE_GAP):
    """
    Agrupa las predicciones en bloques separados por períodos de silencio.
    Un bloque nuevo comienza cuando hay más de `gap_seconds` sin predicciones
    que no sean _silence_.
    """
    active = [(ts, lbl, c) for ts, lbl, c in entries if lbl != '_silence_']
    if not active:
        return []

    blocks = []
    current = [active[0]]
    for i in range(1, len(active)):
        dt = (active[i][0] - active[i-1][0]).total_seconds()
        if dt > gap_seconds:
            blocks.append(current)
            current = [active[i]]
        else:
            current.append(active[i])
    blocks.append(current)
    return blocks


def build_matrix(entries, commands_order, reps):
    """
    Construye la matriz de confusión asignando ground truth
    según el orden de bloques detectados.
    """
    blocks = segment_by_silence(entries)
    n = len(commands_order)
    mat = np.zeros((n, n), dtype=int)

    expected_blocks = n  # un bloque por comando
    actual_blocks   = len(blocks)

    print(f"Bloques detectados: {actual_blocks}  (esperados: {expected_blocks})")
    if actual_blocks != expected_blocks:
        print("⚠  El número de bloques no coincide con los comandos.")
        print("   Ajustá SILENCE_GAP o revisá el log y reintentá.")
        sys.exit(1)

    for cmd_idx, block in enumerate(blocks):
        gt_label = commands_order[cmd_idx]
        gt_idx   = commands_order.index(gt_label)
        print(f"  GT={gt_label:6s}  predicciones={[e[1] for e in block]}")
        for _, pred_label, _ in block:
            if pred_label in commands_order:
                pred_idx = commands_order.index(pred_label)
                mat[gt_idx, pred_idx] += 1

    return mat


def plot_confmat(mat, labels, out_path='informe/figures/confmat_mobile.png'):
    mat_norm = mat.astype(float)
    row_sums = mat_norm.sum(axis=1, keepdims=True)
    row_sums[row_sums == 0] = 1
    mat_norm /= row_sums

    fig, ax = plt.subplots(figsize=(8, 7))
    cmap = plt.cm.Blues
    im = ax.imshow(mat_norm, interpolation='nearest', cmap=cmap, vmin=0, vmax=1)
    plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)

    ax.set_xticks(range(len(labels)))
    ax.set_yticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha='right', fontsize=9)
    ax.set_yticklabels(labels, fontsize=9)
    ax.set_xlabel('Predicción', fontsize=11)
    ax.set_ylabel('Etiqueta real', fontsize=11)
    ax.set_title('Matriz de confusión — dispositivo físico (Samsung Galaxy A71)', fontsize=10)

    thresh = 0.5
    for i in range(len(labels)):
        for j in range(len(labels)):
            val = mat_norm[i, j]
            if val > 0:
                color = 'white' if val > thresh else 'black'
                ax.text(j, i, f'{val:.2f}', ha='center', va='center',
                        fontsize=8, color=color)

    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches='tight')
    print(f"\nImagen guardada en: {out_path}")

    # Métricas por clase
    print("\nRecall por comando:")
    for i, lbl in enumerate(labels):
        total = mat[i].sum()
        if total > 0:
            print(f"  {lbl:12s}: {mat[i,i]/total:.2f}  ({mat[i,i]}/{total})")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python scripts/gen_mobile_confmat.py <mobile_log.txt>")
        sys.exit(1)

    log_path = sys.argv[1]
    print(f"Leyendo: {log_path}")
    entries = parse_logcat(log_path)
    print(f"Predicciones válidas encontradas: {len(entries)}")

    mat = build_matrix(entries, COMMANDS_ORDER, REPS_PER_CMD)
    plot_confmat(mat, COMMANDS_ORDER)
