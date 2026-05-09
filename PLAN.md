# Plan: Voice Command AI — Flutter + ONNX Runtime Mobile + LiteRT-LM

> **Curso:** Inteligencia Artificial — Escuela de Ingeniería en Computación, TEC
> **Repo:** AllanDBB/voice-command-ai
> **Fecha:** Mayo 2026

## Resumen

App Flutter (Android-first) que implementa reconocimiento de comandos de voz completamente on-device en dos capas:

1. **KWS obligatorio (rúbrica):** modelo CNN entrenado en PyTorch sobre espectrogramas Mel del Speech Commands Dataset v2, exportado a ONNX e inferido con **ONNX Runtime Mobile** en Flutter.
2. **NLU bonus (LiteRT-LM):** keyword detectado → **LiteRT-LM** con Tool Use en Kotlin (Android nativo) → acción directa en la UI Smart Home.

**Flujo de datos en producción:**

```
Micrófono → sliding window 1s
  → MelSpectrogram (Dart)
  → ONNX Runtime Mobile → keyword + confianza
  → LiteRT-LM Kotlin (Tool Use) → ToolCall
  → Flutter UI (acción Smart Home)
```

---

## Papers de referencia (Lectures)

| # | Paper | Uso en el proyecto |
|---|---|---|
| 1 | Warden (2018) — *Speech Commands: A Dataset for Limited-Vocabulary Speech Recognition* | Dataset, metodología de evaluación KWS |
| 2 | Park et al. (2019) — *SpecAugment* | Data augmentation para el training pipeline |
| 3 | Lin et al. (2020) — *Training Keyword Spotters with Limited and Synthesized Speech Data* | Análisis de datos sintéticos, speech embeddings |

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Training | Python, PyTorch, torchaudio, WandB |
| Exportación | `torch.onnx.export`, opset 17 |
| Inferencia KWS | ONNX Runtime Mobile (`onnxruntime` pub.dev) |
| Inferencia NLU bonus | LiteRT-LM (`litertlm-android` Gradle) + Tool Use |
| App móvil | Flutter (Dart) — Android-first |
| Audio | `record` package — 16kHz PCM mono |
| State | `provider` |
| Informe | LaTeX IEEE (Overleaf) |

---

## Estructura de carpetas

```
voice-command-ai/
├── lectures/                        ← papers del curso
├── training/
│   └── notebook.ipynb               ← pipeline ML completo
├── app/
│   ├── android/
│   │   └── app/src/main/kotlin/     ← LiteRT-LM plugin nativo
│   ├── ios/
│   ├── assets/models/
│   │   ├── kws_model.onnx           ← modelo exportado
│   │   └── norm_stats.json          ← media/std del preprocesamiento
│   └── lib/
│       ├── domain/
│       ├── application/
│       ├── infrastructure/
│       └── presentation/
└── informe/
    └── main.tex                     ← informe IEEE
```

---

## FASE 0 — Jupyter Notebook: Training Pipeline

> **Entregable académico.** Reproducible, `seed=42` en PyTorch/NumPy/random.

### 0.1 Dataset — Speech Commands v2

- 105K clips, 35 clases, 1s a 16kHz
- Subconjunto: `yes no up down left right on off stop go` + `_silence_` + `_unknown_` = **12 clases**
- Split 80/10/10 estratificado

### 0.2 Preprocesamiento → espectrograma

- `torchaudio.transforms.MelSpectrogram(sample_rate=16000, n_mels=64, n_fft=1024, hop_length=160)` → tensor `64×101`
- `AmplitudeToDB()` → normalizar con media/std del train set
- Guardar `norm_stats.json`: `{"mean": float, "std": float}`

### 0.3 Dataset aumentado — SpecAugment *(Lecture 2)*

- Time masking: `T=40` pasos
- Frequency masking: `F=27` bandas Mel
- Time warp: `τ=80`
- Implementado como `torch.nn.Module` custom (sin librerías externas que abstraigan capas)

### 0.4 Datos sintetizados *(Lecture 3 — bonus académico)*

- Generar variantes TTS con `gTTS`/`pyttsx3`
- YAMNet como speech embedding pre-entrenado (1024 dims)
- Demostrar que synth data mejora accuracy con datos reales limitados

### 0.5 Modelo A — LeNet-5 adaptado *(obligatorio)*

- Entrada: `1 × 64 × 101`
- `Conv2d(1,6,5,padding=2)` → `AvgPool2d(2,2)` → `Conv2d(6,16,5)` → `AvgPool2d(2,2)` → `Flatten` → `Linear→120` → `Linear→84` → `Linear→12`
- Loss: `CrossEntropyLoss`, Optimizer: SGD

### 0.6 Modelo B — MobileNetV3-Small adaptado *(obligatorio)*

- Justificación: diseñado para móvil, ~2.5M params, referencia: Howard et al. 2019
- Primera capa modificada: `Conv2d(1, 16, 3, stride=2)` (entrada 1 canal)
- Loss: `CrossEntropyLoss`, Optimizer: Adam + CosineAnnealingLR

### 0.7 Entrenamiento — 12 runs mínimo con WandB

| Run | Modelo | Dataset | Variable |
|---|---|---|---|
| A1, A2, A3 | LeNet-5 | Base | LR: 0.01 / 0.001 / 0.0001 |
| A4, A5, A6 | LeNet-5 | Aumentado | LR: 0.01 / 0.001 / batch 64 |
| B1, B2, B3 | MobileNetV3 | Base | LR: 1e-3 / 5e-4 / wd: 1e-4 |
| B4, B5, B6 | MobileNetV3 | Aumentado | LR: 1e-3 / 5e-4 / dropout |

- WandB: loguear `loss`, `accuracy`, `val_loss`, `val_acc`, `F1_macro`, `confusion_matrix` cada epoch
- Seleccionar mejor de cada combo por F1-macro en validación
- Comparar 4 finalistas en test set → seleccionar **modelo final**

### 0.8 Exportación a ONNX

```python
model.eval()
dummy = torch.randn(1, 1, 64, 101)
torch.onnx.export(model, dummy, "kws_model.onnx",
    input_names=["spectrogram"], output_names=["logits"],
    dynamic_axes={"spectrogram": {0: "batch"}}, opset_version=17)
```

- Validar: `onnxruntime` Python — 100 test samples — diferencia softmax < 1e-5
- Copiar `kws_model.onnx` + `norm_stats.json` → `app/assets/models/`

---

## FASE 1 — Flutter App Scaffold (Android-first)

```bash
flutter create voice_command_ai --platforms android,ios
```

**`pubspec.yaml`:**

```yaml
dependencies:
  onnxruntime: ^1.x
  record: ^5.x
  provider: ^6.x
  path_provider: ^2.x
  permission_handler: ^11.x
  ffi: ^2.x
flutter:
  assets:
    - assets/models/kws_model.onnx
    - assets/models/norm_stats.json
```

**Arquitectura de capas:**

```
lib/
├── domain/entities/        VoiceCommand, SmartHomeState
├── application/usecases/   ListenAndClassifyUseCase, ExecuteCommandUseCase
├── infrastructure/
│   ├── audio/              AudioCaptureService
│   ├── preprocessing/      MelSpectrogramExtractor
│   ├── inference/          OnnxKWSInterpreter
│   └── lm/                 LiteRTLMService (MethodChannel)
└── presentation/
    ├── screens/             Dashboard, Device, Routines, Confirmation
    └── widgets/             VoiceCommandOverlay, ConfidenceBar, FocusableCard
```

---

## FASE 2 — Audio Pipeline + MelSpectrogram en Dart

> **Crítico:** reproducir exactamente el preprocessing del notebook.

**`AudioCaptureService`:**
- `record` package: 16kHz, mono, PCM-16
- Ring buffer de 16000 samples (1s), avance de 1600 samples (100ms)

**`MelSpectrogramExtractor`** (Dart puro):
- Pre-énfasis → Hann window → FFT 1024 → 64 filtros Mel (20–8000 Hz) → log10
- Normalizar con `norm_stats.json`
- Parámetros idénticos al notebook: `n_mels=64, n_fft=1024, hop_length=160`
- Salida: `Float32List` forma `[1, 1, 64, 101]`

---

## FASE 3 — KWS con ONNX Runtime Mobile *(obligatorio rúbrica)*

**`OnnxKWSInterpreter`:**

```dart
final session = OrtSession.fromAsset('assets/models/kws_model.onnx');
// OrtValueTensor shape [1,1,64,101] → run → softmax → argmax
// retorna VoiceCommand(label, confidence)
```

**`ListenAndClassifyUseCase`:**
- Sliding window: 1s ventana, 200ms slide
- Threshold: confidence >= 0.85
- Cooldown: 600ms entre detecciones válidas

---

## FASE 4 — LiteRT-LM en Android *(bonus — NLU on-device)*

**`android/app/build.gradle`:**

```kotlin
dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-android:latest.release")
}
```

**`LiteRTLMPlugin.kt`** (Kotlin nativo):
- `MethodChannel("litert_lm")` registrado en `MainActivity.kt`
- `Engine(EngineConfig(modelPath, backend = Backend.GPU()))` en coroutine IO
- Modelo: `Gemma3-1B-IT.litertlm` — descarga on-demand desde `litert-community/Gemma3-1B-IT` (HuggingFace)
- Tool Use con anotaciones Kotlin:

```kotlin
class SmartHomeToolSet: ToolSet {
    @Tool(description = "Navigate between UI elements")
    fun navigate(@ToolParam("direction: up/down/left/right") direction: String): Map<String, Any>

    @Tool(description = "Toggle device state")
    fun toggleDevice(
        @ToolParam("device name") device: String,
        @ToolParam("on or off") state: String
    ): Map<String, Any>

    @Tool(description = "Control a routine")
    fun controlRoutine(
        @ToolParam("routine name") routine: String,
        @ToolParam("go or stop") action: String
    ): Map<String, Any>

    @Tool(description = "Confirm or cancel action")
    fun confirm(@ToolParam("yes or no") answer: String): Map<String, Any>
}
```

System prompt: `"You are a Smart Home voice assistant. The user said: '<keyword>'. Call the appropriate tool."`

**`LiteRTLMService.dart`:**
- `MethodChannel('litert_lm')`
- `Future<SmartHomeAction> interpretKeyword(String keyword)`
- Fallback estático si LM no responde en 3s

**`AndroidManifest.xml`** (para GPU backend):

```xml
<uses-native-library android:name="libvndksupport.so" android:required="false"/>
<uses-native-library android:name="libOpenCL.so" android:required="false"/>
```

---

## FASE 5 — Smart Home UI (4 pantallas navegables por voz)

### Mapa de comandos → acciones UI

| Comando | Acción |
|---|---|
| `up / down / left / right` | Mover foco visual entre opciones (`FocusableCard`) |
| `yes` | Confirmar / seleccionar opción en foco |
| `no` | Cancelar / volver |
| `on / off` | Toggle dispositivo en DeviceScreen |
| `go / stop` | Iniciar / detener rutina en RoutinesScreen |

### DashboardScreen *(Figura 3 del enunciado)*
- Grid: Luces, Ventilador, TV, Rutinas
- `up/down/left/right` → mover foco; `yes` → entrar; `no` → no-op

### DeviceScreen *(Figura 4 del enunciado)*
- Dispositivo seleccionado + estado ON/OFF + animación toggle
- `on/off` → cambiar estado; `left` → volver al Dashboard

### RoutinesScreen *(Figura 5 del enunciado)*
- Lista de rutinas: Mañana, Noche, Cine
- `up/down` → navegar lista; `go` → iniciar; `stop` → detener

### ConfirmationScreen *(Figura 6 del enunciado)*
- Modal de confirmación para acciones sensibles
- `yes` → confirmar; `no` → cancelar

### VoiceCommandOverlay *(widget global)*
- Barra inferior: ícono micrófono + keyword detectado + `ConfidenceBar`
- Estados: `idle` (gris) / `listening` (azul pulsante) / `detected` (verde)

---

## FASE 6 — Informe LaTeX IEEE (Overleaf)

**Secciones:**
1. Introducción
2. Dataset (Speech Commands v2)
3. Preprocesamiento (Mel Spectrogram)
4. Data Augmentation (SpecAugment, justificado con Park et al. 2019)
5. Arquitecturas: Modelo A (LeNet-5) + Modelo B (MobileNetV3) — diagramas
6. Entrenamiento: tabla de 12 runs, curvas loss/accuracy, análisis overfitting
7. Evaluación con WandB: screenshots dashboard, matrices de confusión
8. Exportación ONNX y validación numérica
9. Integración móvil: arquitectura, screenshots, demo navegación por voz
10. LiteRT-LM bonus: NLU on-device, Tool Use
11. Conclusiones
12. Referencias IEEE: Park et al., Warden, Lin et al., Howard et al. (MobileNetV3)

---

## FASE 7 — Verificación

| Check | Criterio |
|---|---|
| ONNX vs PyTorch | 100 test samples → diferencia softmax < 1e-5 |
| MelSpec Dart vs Python | mismo `.wav` → RMSE < 1e-3 |
| WandB 12 runs | todos registrados con métricas completas |
| F1-macro test | modelo final >= 80% en 12 clases |
| Prueba funcional Android | 10 comandos → navegación correcta |
| LiteRT-LM latencia | keyword → acción <= 4s en dispositivo físico |
| Entregable .zip | LaTeX + PDF + notebook + código app |

---

## Archivos clave a crear

| Archivo | Descripción |
|---|---|
| `training/notebook.ipynb` | Pipeline ML completo: data → 12 runs WandB → ONNX |
| `app/assets/models/kws_model.onnx` | Mejor modelo exportado |
| `app/assets/models/norm_stats.json` | Parámetros de normalización |
| `app/lib/infrastructure/preprocessing/mel_spectrogram_extractor.dart` | MelSpec en Dart |
| `app/lib/infrastructure/inference/onnx_kws_interpreter.dart` | ONNX Runtime wrapper |
| `app/android/app/src/main/kotlin/.../LiteRTLMPlugin.kt` | Engine + ToolSet Kotlin |
| `app/lib/infrastructure/lm/litert_lm_service.dart` | MethodChannel Dart |
| `app/lib/presentation/screens/dashboard_screen.dart` | Pantalla principal |
| `app/lib/presentation/screens/device_screen.dart` | Control dispositivos |
| `app/lib/presentation/screens/routines_screen.dart` | Rutinas |
| `app/lib/presentation/screens/confirmation_screen.dart` | Confirmación |
| `informe/main.tex` | Informe IEEE |

---

## Rúbrica vs plan

| Criterio rúbrica | Puntaje | Cubierto en |
|---|---|---|
| Diseño y arquitectura Modelo A | 5 | Fase 0.5 + Informe §5 |
| Diseño y arquitectura Modelo B | 10 | Fase 0.6 + Informe §5 |
| Selección de técnicas de aumentación | 10 | Fase 0.3 + Informe §4 |
| Entrenamiento crudo + aumentado Modelo A | 15 | Fase 0.7 (runs A1–A6) |
| Entrenamiento crudo + aumentado Modelo B | 15 | Fase 0.7 (runs B1–B6) |
| Métricas y selección mejor Modelo A | 10 | Fase 0.7 + WandB |
| Métricas y selección mejor Modelo B | 10 | Fase 0.7 + WandB |
| Comparación modelos finales | 10 | Fase 0.8 |
| Integración en app móvil | 15 | Fases 1–5 |
| **Total** | **100** | |

---

## Dependencias entre fases

```
Fase 0 (notebook) ──────────────────────────────► Fase 6 (informe, en paralelo)
     │
     └── kws_model.onnx + norm_stats.json
          │
Fase 1 (scaffold) ──► Fase 2 (audio+melspec) ──► Fase 3 (ONNX KWS) ──► Fase 5 (UI)
                                                          │
                                                     Fase 4 (LiteRT-LM, bonus)
```
