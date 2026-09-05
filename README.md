# Stay In Line!

`Stay In Line!` is a soft pastel, top-down game set during an idol fan event in a garden plaza. Explore the event, earn Fan Score, survive the moving queue minigame, and submit enough score to complete three event rounds.

As the event continues, discarded bottles accumulate around the plaza. Completing the third round reveals the full environmental cost behind the celebration.

## Running the Game

1. Open `project.godot` with Godot 4.6 or a compatible Godot 4 version.
2. Press **F6** to run the open scene or **F5** to run the full game.
3. Choose **Start New Game** on the title screen.
4. Use **Continue** to resume saved progress. After clearing the game, this button becomes **View Ending**.

## Controls

### Main Plaza

| Action | Keyboard / Mouse |
| --- | --- |
| Move | **WASD** or **Arrow Keys** |
| Enter the queue minigame | Stand near the queue entrance and press **W** or **Up Arrow** |
| Submit event score | Click **Submit Event Score** |
| Pause / resume | **Escape** |
| Use menu buttons | Mouse, or keyboard focus with **Enter** |

The scattered bottles have physics. Walking into a bottle pushes it across the ground.

### Stay In Line Minigame

| Action | Keyboard |
| --- | --- |
| Move | **WASD** or **Arrow Keys** |
| Use a drink shield | **E** |
| Pause / resume | **Escape** |
| Confirm Retry / Return | **Enter** when the button is focused, or click it |

## Main Game Loop

1. Explore the garden plaza and collect score pickups.
2. Find the queue entrance near the event registration area.
3. Press **W** or **Up Arrow** to enter **Stay In Line**.
4. Complete the queue challenge to earn **10 Fan Score**.
5. Return to the plaza and click **Submit Event Score**.
6. Confirm the submission. Each submission costs **10 Fan Score** and completes one event round.
7. Repeat the queue and submission loop until all **3 rounds** are complete.

The full event target is **30 submitted score**, divided into three 10-point rounds.

## How to Play Stay In Line

The queue moves along a fixed path toward the finish. Your goal is to stay inside its safe area while avoiding incoming hazards.

### Win Condition

- Stay inside the moving queue area.
- Keep pace as the queue follows its route.
- Dodge incoming obstacles and projectiles.
- Reach the goal area at the end of the route.

A successful run displays **You stayed in line!**, awards 10 Fan Score, and returns you to the main plaza.

### Failure Conditions

You fail the attempt if you:

- Leave the queue after entering it.
- Touch an obstacle or projectile without an active drink shield.

After failing, use the on-screen **Retry** button. You have up to three failed attempts before the game returns you to the plaza. A failure does not award score.

### Drink Shield

- Press **E** to activate the drink shield.
- Each queue visit starts with **2 uses**.
- The shield lasts for **3 seconds**.
- While active, obstacle hits are ignored.
- The shield does **not** protect you from leaving the queue.

The drink icon and buff timer show the remaining uses and protection time.

## Three-Round Progression

| Completed rounds | Plaza change |
| --- | --- |
| 0 | The plaza begins clean. |
| 1 | The first group of discarded bottles appears. |
| 2 | More bottle litter appears around paths and event areas. |
| 3 | The final litter group and backstage garbage dump are revealed. |

After the third submission, the camera reveals the backstage waste area before opening the **Game Clear** screen.

## Score and Saving

- Queue victory: **+10 Fan Score**.
- Plaza score pickup: **+1 Fan Score**.
- Event submission: costs **10 Fan Score** and completes one round.
- Round progress, total score, queue difficulty, attempts, and the cleared state are saved automatically.
- **Start New Game** and **Restart Event** reset progression.

## Tips

- Stay near the center of the moving queue instead of following its outer edge.
- Make small corrections; diagonal movement is useful when the path bends.
- Save the drink shield for dense obstacle patterns.
- The shield blocks obstacles, but you must still remain inside the queue.
- If a score submission does not work, check that you have at least 10 Fan Score.

## Developer Testing Shortcuts

These shortcuts work only in editor/debug builds and are not part of the normal game rules.

| Shortcut | Effect |
| --- | --- |
| **Ctrl + Shift + F8** | Adds 10 Fan Score without recording a queue attempt or victory. |
| **F10** or the grave-accent key | Opens or closes the debug console. |

Useful console commands:

```text
addScore 30
resetProgress
godmode
godmode on
godmode off
```

`resetProgress` returns the save to round 0 with 0 score. `godmode` prevents queue hazards and leaving the queue from causing failure while enabled.
