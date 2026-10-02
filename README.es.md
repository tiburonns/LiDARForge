# LiDARForge

LiDARForge es un espacio de captura espacial **local-first** para iPhone y iPad equipados con LiDAR.

En lugar de ofrecer un único botón genérico de escaneo, LiDARForge organiza la captura según el **tipo de proyecto** y guía al usuario mediante tres pasadas:

1. **Estructura** — geometría, bordes, escala y tracking.
2. **Detalle** — volver a zonas con vistas incompletas o baja confianza.
3. **Apariencia** — capturar información visual para texturas y fotogrametría.

## Tipos de proyecto

- **Objeto** — objetos físicos pequeños y medianos.
- **Interior** — habitaciones y espacios interiores.
- **Exterior** — exteriores, fachadas, vehículos y estructuras.
- **Edificio** — captura arquitectónica por habitaciones o zonas.
- **Video 3D / RGB-D** — RGB, profundidad, confianza, pose, intrínsecos y timestamps sincronizados.

## Herramientas de sensor

La primera implementación incluye:

- Cámara
- Cámara + puntos
- Malla LiDAR
- Vista de profundidad
- Vista de confianza
- Métricas crudas del sensor
- Visualización tipo visión nocturna mediante profundidad
- Estimación de cobertura
- Guía de velocidad y distancia adaptada al tipo de proyecto
- ROI de objeto fijado por toque con filtrado de fondo
- Mapa direccional de cobertura de 24 sectores para objetos
- Informe de Salud del escaneo con recomendaciones prácticas
- Modos de calidad Rápido / Equilibrado / Máximo
- Acumulación de nube de puntos densa desde SceneDepth con respaldo de puntos AR
- Métricas de tracking y malla
- Selector personalizable de funciones y herramientas con visibilidad y orden persistentes

## Hito actual — 0.2 Inteligencia de captura

El repositorio contiene una aplicación iOS para Xcode con iOS 17+:

- Interfaz SwiftUI
- Selector Español / English / Sistema
- Selector por tipo de proyecto
- Flujo guiado Estructura → Detalle → Apariencia
- Sesión LiDAR con ARKit + RealityKit
- Scene Depth y Smoothed Scene Depth cuando el dispositivo los soporta
- Reconstrucción de malla cuando está disponible
- Métricas en vivo de puntos, malla y tracking
- Previsualización de profundidad y mapa de confianza
- Persistencia de snapshots del proyecto en JSON
- Biblioteca de proyectos guardados con eliminación
- Captura estructural RoomPlan para proyectos de Interior
- Resumen RoomPlan, completitud estructural, vista de plano 2D y exportación de malla USDZ
- Captura RoomPlan multi-habitación con combinación mediante StructureBuilder
- Exportación y compartición PLY densa desde SceneDepth
- Flujo de apariencia con RealityKit ObjectCaptureSession: detección, pasadas guiadas, vista de nube de puntos, nueva pasada/volteo y compartición
- Grabación de datasets RGB-D locales dentro de paquetes `.lidarforge`
- Persistencia de nubes de puntos por proyecto y paquetes `.lidarforge` compartibles
- Persistencia de ARWorldMap, ROI del objeto, mediciones y muestras 3D de cobertura por superficie
- Archivos de fuentes RGB/profundidad/confianza/pose/intrínsecos/timestamps/IMU por proyecto para reprocesado posterior
- Coach de perspectiva faltante derivado de cobertura direccional y superficies de la malla
- Pantalla de detalle de proyecto con progreso y continuación del flujo
- Recuperación de pausa/reanudación e interrupciones sin descartar intencionalmente el escaneo actual
- Pantalla de herramientas del sensor
- Workflow CI de compilación

> Las funciones LiDAR requieren un dispositivo físico compatible. El simulador puede compilar la interfaz, pero no proporciona datos LiDAR.

## Próximos hitos

- Refinamiento del heatmap de superficie con detección explícita de oclusiones
- Heatmap de confianza de profundidad proyectado en la geometría
- Exportación y conversión de malla
- Pipeline OBJ / STL / GLB / XYZ / LAS
- Exportación arquitectónica PDF / SVG / DXF
- QA en dispositivo físico, rendimiento, accesibilidad y endurecimiento para TestFlight

Consulta [docs/ROADMAP.md](docs/ROADMAP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) y [docs/DEVICE_TEST_PLAN.md](docs/DEVICE_TEST_PLAN.md).

## Privacidad

La arquitectura es **local-first**. Los frames del sensor y los proyectos permanecen en el dispositivo hasta que el usuario decide exportarlos o compartirlos.

## Idiomas

- Español
- English
- Idioma del sistema

## Licencia

MIT — consulta [LICENSE](LICENSE).
