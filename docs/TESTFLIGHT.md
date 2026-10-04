# LiDARForge TestFlight preflight / Preflight de TestFlight

## English

LiDARForge 0.2.0 (build 1) should enter Internal TestFlight only after the source gate and a physical LiDAR-device pass are complete.

### Automated/source gate

CI validates:

- Info.plist and Privacy Manifest;
- English/Spanish camera and motion permission copy;
- release/version contract;
- warning-free **Release** build for iOS Simulator;
- warning-free **Release** build for generic iPhoneOS;
- Xcode static analysis.

The simulator can validate compilation and UI paths, but it cannot certify ARKit SceneDepth, mesh reconstruction, RoomPlan, Object Capture, RGB-D synchronization or thermal behavior.

### Physical acceptance

Run `docs/DEVICE_TEST_PLAN.md` on at least one LiDAR-equipped iPhone or iPad. Before upload, specifically verify:

- camera and motion permission grant/deny/recovery;
- Structure → Detail → Appearance progression;
- camera remains live when changing stages or opening details/options;
- SceneDepth/confidence/mesh/feature-point tools;
- pause/resume and AR interruption recovery;
- ARWorldMap relocalization after leaving/reopening a project;
- PLY export and .lidarforge package share/import round trip;
- RoomPlan on Interior/Building projects;
- Object Capture appearance pass where supported;
- RGB-D archive integrity;
- 10–15 minute Fast/Balanced/Maximum sessions without reproducible crash or runaway memory growth;
- portrait/landscape safe-area behavior;
- System / English / Español.

### Archive

1. Pull the tested revision.
2. Open `LiDARForge.xcodeproj`.
3. Select the paid Apple Developer Team.
4. Confirm bundle identifier `com.tiburonns.LiDARForge`.
5. Select Generic iOS Device.
6. Product → Archive.
7. Organizer → Validate App.
8. Upload to App Store Connect.
9. Begin with Internal Testing.

LiDARForge is local-first. Sensor/project data remains local unless the user explicitly exports or shares it.

---

## Español

LiDARForge 0.2.0 (build 1) sólo debe entrar a Internal TestFlight después de completar el gate de código y una pasada física en un dispositivo con LiDAR.

### Gate automatizado/de código

CI valida:

- Info.plist y Privacy Manifest;
- textos de permisos de cámara y movimiento en inglés/español;
- contrato de versión/release;
- build **Release** sin warnings para Simulator;
- build **Release** sin warnings para iPhoneOS genérico;
- análisis estático de Xcode.

El simulador puede validar compilación e interfaz, pero no certifica SceneDepth, reconstrucción de mesh, RoomPlan, Object Capture, sincronización RGB-D ni comportamiento térmico.

### Aceptación física

Ejecuta `docs/DEVICE_TEST_PLAN.md` en al menos un iPhone o iPad con LiDAR. Antes de subir, verifica específicamente:

- permisos de cámara/movimiento: aceptar, negar y recuperar;
- flujo Estructura → Detalle → Apariencia;
- cámara activa al cambiar etapa o abrir detalles/opciones;
- SceneDepth/confianza/mesh/puntos;
- pausa/reanudación e interrupciones AR;
- relocalización ARWorldMap después de salir/reabrir;
- exportación PLY y round trip compartir/importar .lidarforge;
- RoomPlan en Interior/Building;
- Object Capture donde sea compatible;
- integridad del archivo RGB-D;
- sesiones Fast/Balanced/Maximum de 10–15 minutos sin crash reproducible ni crecimiento de memoria fuera de control;
- safe areas en vertical/horizontal;
- Sistema / English / Español.

### Archive

1. Actualiza a la revisión probada.
2. Abre `LiDARForge.xcodeproj`.
3. Selecciona tu Team de Apple Developer de pago.
4. Confirma `com.tiburonns.LiDARForge`.
5. Selecciona Generic iOS Device.
6. Product → Archive.
7. Organizer → Validate App.
8. Sube a App Store Connect.
9. Empieza con Internal Testing.

LiDARForge es local-first. Los datos de sensores/proyectos permanecen locales salvo que el usuario los exporte o comparta explícitamente.
