# LiDARForge Physical Device Test Plan

This checklist covers behavior that cannot be validated by the iOS Simulator or GitHub Actions. Run it on a LiDAR-equipped iPhone or iPad.

## 1. 3D Surface Coverage

1. Create an Object, Interior, and Exterior project.
2. Enable **3D Coverage Heatmap**.
3. Scan a surface from one viewpoint.
4. Confirm red/yellow markers appear on weakly observed reconstructed surfaces.
5. Revisit those surfaces from overlapping viewpoints.
6. Confirm markers progress toward green and the Surface Coverage score increases.
7. Hide and show the heatmap from the scanner quick tools.
8. Save the project, close the scanner, reopen the project, and confirm saved heatmap state is restored.

Expected:
- Heatmap markers remain registered to world-space surfaces.
- Marker updates do not cause major tracking stalls.
- Coverage does not jump to 100% after a single frame.

## 2. Missing Viewpoint Coach

### Object
1. Lock an object target.
2. Scan only the front and one side.
3. Confirm Missing Viewpoint recommends a horizontal move and camera height.
4. Follow the guidance.
5. Confirm the recommendation changes as weak sectors are filled.

### Interior / Exterior
1. Scan a wall or facade incompletely.
2. Confirm the coach identifies a weak reconstructed surface.
3. Follow left/right/high/low guidance.
4. Verify surface coverage improves.

Expected:
- Guidance changes with camera pose and coverage.
- The recommendation disappears when no meaningful weak cell remains.

## 3. Project Persistence

1. Enable **Source Archive**.
2. Start a normal project and scan for at least 30 seconds.
3. Save the project.
4. Verify Project Details reports the spatial map, source sessions, point cloud when available, and saved surface coverage.
5. Leave the project and reopen it.
6. Point the device at the previously scanned area until ARKit relocalizes.
7. Confirm measurements, object ROI, heatmap state, and project stage return.
8. Continue scanning and save again.
9. Build and share the .lidarforge package.

Expected project content may include:

```text
project.json
worldmap.arexperience
pointcloud/
sources/
  capture-*/
    rgb/
    depth/
    confidence/
    metadata/frames.jsonl
    metadata/imu.jsonl
    dataset.json
manifest.json
```

## 4. Source Archive Validation

- RGB frame count should match metadata records.
- Depth files should exist for frames where SceneDepth was available.
- Confidence files should match depth dimensions.
- Each metadata record should contain timestamp, camera transform, intrinsics, RGB dimensions, and depth dimensions when available.
- IMU JSONL should contain attitude quaternion, rotation rate, user acceleration, gravity, and timestamps when CoreMotion is available.

## 5. Custom Tool Selector

1. Open Settings → Customize Tools.
2. Disable Measurements, Raw Inspector, and Confidence View.
3. Reorder Scan Health and 3D Coverage Heatmap.
4. Return to the scanner.
5. Confirm disabled capture functions are absent and enabled functions use the chosen order.
6. Confirm disabled sensor modes are removed from the scanner mode picker.
7. Open Sensor Tools and confirm its order matches the preference.
8. Relaunch the app and confirm preferences persist.
9. Use Reset Tool Layout and confirm defaults return.

## 6. Thermal / Long Session

For each Fast, Balanced, and Maximum mode:

1. Scan continuously for 10–15 minutes.
2. Observe thermal warnings and tracking.
3. Pause/resume.
4. Background/foreground the app once.
5. Trigger another AR interruption if practical.
6. Continue and save.

Record device temperature behavior, memory pressure or termination, point count, source archive size, relocalization behavior, visible frame drops, and any unresponsive controls.

## 7. Acceptance Gate

Before TestFlight:
- no reproducible crash in the workflows above;
- project package opens/shares successfully;
- ARWorldMap resume succeeds in representative indoor scenes;
- Source Archive produces readable metadata and sensor files;
- heatmap remains spatially stable;
- tool preferences survive relaunch;
- Fast/Balanced/Maximum all complete a 10-minute scan;
- camera and motion permission descriptions appear correctly.