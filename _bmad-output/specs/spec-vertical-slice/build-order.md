# Build Order

Suggested sequence from GDD §15. Each step is a natural story boundary.

1. Godot project skeleton with pixel-art settings and a 3×3 grid on screen
2. Part palette and drag-and-drop placement onto the grid
3. Part and card data files
4. Run resolver as pure logic, testable without visuals (install GUT here)
5. Run playback scene with log and speed controls
6. Win/loss screen with "Rebuild" and "Retry same seed"
7. Tuning pass using the data files
