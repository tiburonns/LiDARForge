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
- **Video 3D / RGB-D** — color + profundidad sincronizados (planeado).

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

## Hito actual — 0.1 Foundation

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
- Resumen de habitación RoomPlan y exportación de malla USDZ
- Exportación y compartición PLY densa desde SceneDepth
- Recuperación de pausa/reanudación e interrupciones sin descartar intencionalmente el escaneo actual
- Pantalla de herramientas del sensor
- Workflow CI de compilación

> Las funciones LiDAR requieren un dispositivo físico compatible. El simulador puede compilar la interfaz, pero no proporciona datos LiDAR.

## Próximos hitos

- Guía de completitud de habitación y vista de plano 2D
- Fotogrametría guiada con Object Capture
- Mapa de cobertura por superficie
- Grabación RGB-D
- Proyectos de edificios con varias habitaciones
- Exportación de mallas
- USDZ / OBJ / GLB
- Exportación de datasets crudos
- Paquete de proyecto `.lidarforge`

Consulta [docs/ROADMAP.md](docs/ROADMAP.md) y [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Privacidad

La arquitectura es **local-first**. Los frames del sensor y los proyectos permanecen en el dispositivo hasta que el usuario decide exportarlos o compartirlos.

## Idiomas

- Español
- English
- Idioma del sistema

## Licencia

MIT — consulta [LICENSE](LICENSE).
