# Build Order

This is the sequence from GDD §15 with steps 2 and 3 swapped, so the palette reads its parts from data. Each step is one story.

1. Godot project skeleton with pixel-art settings and a 3×3 grid on screen
2. Part and card data files
3. Part palette and drag-and-drop placement onto the grid
4. Run resolver as pure logic, testable without visuals (install GUT here)
5. Run playback scene with log and speed controls
6. Win/loss screen with "Rebuild" and "Retry same seed"
7. Tuning pass using the data files
