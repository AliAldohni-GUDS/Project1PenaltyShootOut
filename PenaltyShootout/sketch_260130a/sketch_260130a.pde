/**
 * PROJECT 1 – Penalty Shootout (Processing / Java Mode)
 * -----------------------------------------------------
 * Controls:
 *  MENU:
 *   - 1 / 2 / 3 : Select difficulty (Easy / Normal / Hard)
 *   - ENTER     : Start game
 *
 *  IN GAME:
 *   - LEFT / RIGHT : aim
 *   - UP / DOWN    : power
 *   - SPACE        : shoot
 *   - R            : next shot (after result)
 *   - M            : back to menu
 *   - X            : full reset (score + history)
 */

Player player;
Ball ball;
Goalkeeper keeper;
Goal goal;

int score = 0;
int saves = 0;
int shots = 0;

ArrayList<Float> shotXHistory = new ArrayList<Float>();     // Arrays topic
ArrayList<Boolean> shotGoalHistory = new ArrayList<Boolean>();

// Global states
final int STATE_MENU = 0;
final int STATE_AIM = 1;
final int STATE_SHOOTING = 2;
final int STATE_RESULT = 3;
int state = STATE_MENU;

String resultText = "";
float lastGoalChance = 0;

// Difficulty
final int DIFF_EASY = 0;
final int DIFF_NORMAL = 1;
final int DIFF_HARD = 2;
int difficulty = DIFF_NORMAL;

// Tuned by difficulty
float keeperSpeed = 3.2;       // how fast keeper moves to committed target
float keeperError = 110;       // how wrong keeper can commit (higher = easier for player)
float goalChanceMin = 0.38;    // probability lower bound when shot near keeper
float goalChanceMax = 0.98;    // probability upper bound when shot far from keeper

void setup() {
  size(900, 600);
  smooth(8);
  textFont(createFont("Arial", 16));

  goal = new Goal(width*0.2, 80, width*0.6, 120); // x, y, w, h
  player = new Player(width*0.5, height - 90);
  ball = new Ball(player.x, player.y - 20);

  keeper = new Goalkeeper(
    goal.x + goal.w*0.5,
    goal.y + goal.h - 25,
    goal.x + 25,
    goal.x + goal.w - 25
  );

  applyDifficulty(difficulty);
}

void draw() {
  background(20, 130, 60);

  if (state == STATE_MENU) {
    drawMenu();
    return;
  }

  drawPitch();
  goal.draw();

  // If aiming, keep ball on spot
  if (state == STATE_AIM) {
    ball.reset(player.x, player.y - 22);
  }

  // Update keeper and ball
  keeper.update(state, ball, goal);
  ball.update(state);

  // Resolve once ball crosses the goal line plane
  if (state == STATE_SHOOTING && ball.justCrossedGoalLine(goal)) {
    resolveShot();
  }

  // Draw entities
  keeper.draw();
  player.draw();
  ball.draw();

  if (state == STATE_AIM) player.drawAimUI();

  drawHUD();
  drawResultBanner();
}

void keyPressed() {
  // MENU CONTROLS
  if (state == STATE_MENU) {
    if (key == '1') { difficulty = DIFF_EASY; applyDifficulty(difficulty); }
    if (key == '2') { difficulty = DIFF_NORMAL; applyDifficulty(difficulty); }
    if (key == '3') { difficulty = DIFF_HARD; applyDifficulty(difficulty); }

    if (keyCode == ENTER || keyCode == RETURN) {
      // start game
      fullReset();
      state = STATE_AIM;
    }
    return;
  }

  // Always allow menu back / full reset
  if (key == 'm' || key == 'M') {
    state = STATE_MENU;
    return;
  }
  if (key == 'x' || key == 'X') {
    fullReset();
    state = STATE_AIM;
    return;
  }

  // GAME CONTROLS
  if (state == STATE_AIM) {
    if (keyCode == LEFT)  player.aimAngle -= 0.06;
    if (keyCode == RIGHT) player.aimAngle += 0.06;
    if (keyCode == UP)    player.power = min(14, player.power + 0.5);
    if (keyCode == DOWN)  player.power = max(6, player.power - 0.5);

    // clamp aim range
    player.aimAngle = constrain(player.aimAngle, radians(-70), radians(70));

    if (key == ' ') {
      ball.shoot(player.aimAngle, player.power);
      state = STATE_SHOOTING;
      shots++;

      // keeper commits early ONCE per shot (option A)
      keeper.commitToShot(ball, goal, keeperError);
    }
  } else if (state == STATE_RESULT) {
    if (key == 'r' || key == 'R') resetForNextShot();
  }
}

void applyDifficulty(int diff) {
  if (diff == DIFF_EASY) {
    keeperSpeed = 2.6;
    keeperError = 150;      // keeper commits with bigger mistake -> more goals
    goalChanceMin = 0.42;
    goalChanceMax = 0.99;
  } else if (diff == DIFF_NORMAL) {
    keeperSpeed = 3.2;
    keeperError = 110;
    goalChanceMin = 0.38;
    goalChanceMax = 0.98;
  } else { // HARD
    keeperSpeed = 3.9;
    keeperError = 70;       // keeper commits closer to true ball -> more saves
    goalChanceMin = 0.30;
    goalChanceMax = 0.95;
  }

  keeper.baseSpeed = keeperSpeed;
}

void resolveShot() {
  boolean insideGoal = goal.containsX(ball.x);

  // Distance between impact X and keeper X drives probability
  float distToKeeper = abs(ball.x - keeper.x);
  float norm = constrain(distToKeeper / (goal.w * 0.5), 0, 1);

  float goalChance = insideGoal ? lerp(goalChanceMin, goalChanceMax, norm) : 0.0;
  lastGoalChance = goalChance;

  boolean isGoal = insideGoal && (random(1) < goalChance);

  // History arrays
  shotXHistory.add(ball.x);
  shotGoalHistory.add(isGoal);

  if (isGoal) {
    score++;
    resultText = "GOAL!  (chance: " + nf(goalChance*100, 0, 0) + "%)";
  } else {
    saves++;
    resultText = insideGoal ? "SAVED! (chance: " + nf(goalChance*100, 0, 0) + "%)" : "MISS! (outside goal)";
  }

  state = STATE_RESULT;
  ball.stop();

  // Freeze keeper in final dive pose briefly (handled in keeper.update by state)
}

void resetForNextShot() {
  state = STATE_AIM;
  resultText = "";
  lastGoalChance = 0;
  keeper.reset();
  ball.reset(player.x, player.y - 22);
}

void fullReset() {
  score = 0;
  saves = 0;
  shots = 0;
  shotXHistory.clear();
  shotGoalHistory.clear();
  resetForNextShot();
}

void drawMenu() {
  // Simple menu screen
  background(12, 90, 45);
  fill(255);
  textAlign(CENTER, CENTER);

  textSize(34);
  text("Penalty Shootout", width*0.5, 110);

  textSize(16);
  text("Select difficulty, then press ENTER to start", width*0.5, 160);

  // Difficulty options
  float y0 = 240;
  drawDifficultyOption("1) EASY",   DIFF_EASY,   y0);
  drawDifficultyOption("2) NORMAL", DIFF_NORMAL, y0 + 52);
  drawDifficultyOption("3) HARD",   DIFF_HARD,   y0 + 104);

  // Short explanation
  textSize(13);
  fill(255, 220);
  text("Easy: keeper slower + bigger mistakes", width*0.5, 430);
  text("Hard: keeper faster + commits closer to the ball", width*0.5, 450);

  fill(255, 230);
  text("In game: Aim ←/→, Power ↑/↓, Shoot SPACE, Next shot R, Menu M, Reset X", width*0.5, 510);
}

void drawDifficultyOption(String label, int diff, float y) {
  boolean selected = (difficulty == diff);
  noStroke();
  fill(selected ? color(255, 210, 0) : color(0, 0, 0, 120));
  rectMode(CENTER);
  rect(width*0.5, y, 280, 40, 10);

  fill(selected ? 20 : 255);
  textSize(18);
  text(label, width*0.5, y);
  rectMode(CORNER);
}

void drawPitch() {
  stroke(255, 180);
  strokeWeight(2);
  noFill();

  float boxW = goal.w * 1.3;
  float boxH = 220;
  float boxX = width*0.5 - boxW*0.5;
  float boxY = goal.y + goal.h;
  rect(boxX, boxY, boxW, boxH);

  noStroke();
  fill(255);
  circle(width*0.5, height - 110, 6);

  stroke(255, 70);
  line(width*0.5, 0, width*0.5, height);
}

void drawHUD() {
  fill(255);
  textSize(14);
  textAlign(LEFT, TOP);

  String d = (difficulty == DIFF_EASY) ? "EASY" : (difficulty == DIFF_HARD) ? "HARD" : "NORMAL";
  text("Difficulty: " + d + "   Shots: " + shots + "   Goals: " + score + "   Saves/Misses: " + saves, 16, 14);

  text("Aim: ←/→  Power: ↑/↓  Shoot: SPACE  Next shot: R  Menu: M  Reset: X", 16, 34);

  // History markers (last 10)
  int n = min(10, shotXHistory.size());
  float startX = 16;
  float y = 60;

  fill(255, 220);
  text("Last shots:", startX, y);
  y += 18;

  for (int i = 0; i < n; i++) {
    int idx = shotXHistory.size() - n + i;
    float sx = shotXHistory.get(idx);
    boolean g = shotGoalHistory.get(idx);

    float mx = map(sx, goal.x, goal.x + goal.w, startX, startX + 220);
    noStroke();
    fill(g ? color(60, 220, 90) : color(240, 80, 80));
    rect(mx, y, 10, 10);
  }
}

void drawResultBanner() {
  if (state != STATE_RESULT) return;

  noStroke();
  fill(0, 160);
  rect(0, height - 70, width, 70);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(22);
  text(resultText, width*0.5, height - 40);

  textSize(14);
  text("Press R for next shot (or M for menu)", width*0.5, height - 18);
}

/* ========================= CLASSES ========================= */

class Player {
  float x, y;
  float aimAngle = 0;
  float power = 10;

  Player(float x, float y) {
    this.x = x;
    this.y = y;
  }

  void draw() {
    noStroke();
    fill(30, 30, 40);
    ellipse(x, y, 26, 26);
    fill(255);
    ellipse(x - 5, y - 4, 4, 4);
    ellipse(x + 5, y - 4, 4, 4);
  }

  void drawAimUI() {
    // Transformation topic: translate/rotate aiming arrow
    pushMatrix();
    translate(x, y - 12);
    rotate(aimAngle);

    stroke(255, 230);
    strokeWeight(3);
    line(0, 0, 0, -60);
    line(0, -60, -7, -50);
    line(0, -60, 7, -50);

    popMatrix();

    // power bar
    float barW = 120;
    float barH = 10;
    float px = x - barW/2;
    float py = y + 26;

    noStroke();
    fill(0, 160);
    rect(px, py, barW, barH, 6);

    float t = map(power, 6, 14, 0, 1);
    fill(255, 210, 0);
    rect(px, py, barW * t, barH, 6);

    fill(255);
    textAlign(CENTER, TOP);
    textSize(12);
    text("POWER", x, py + 14);
  }
}

class Ball {
  float x, y;
  float vx, vy;
  float r = 10;
  float prevY;
  boolean moving = false;

  Ball(float x, float y) {
    reset(x, y);
  }

  void reset(float x, float y) {
    this.x = x;
    this.y = y;
    vx = 0;
    vy = 0;
    prevY = y;
    moving = false;
  }

  void shoot(float angle, float power) {
    vx = sin(angle) * power;
    vy = -cos(angle) * power;
    moving = true;
  }

  void stop() {
    vx = 0;
    vy = 0;
    moving = false;
  }

  void update(int state) {
    prevY = y;

    if (state == STATE_SHOOTING && moving) {
      vx *= 0.995;
      vy *= 0.995;

      x += vx;
      y += vy;

      // subtle gravity
      vy += 0.05;

      // side bounce to keep visible
      if (x < r) { x = r; vx *= -0.6; }
      if (x > width - r) { x = width - r; vx *= -0.6; }

      if (y > height + 80 || y < -80) {
        moving = false;
      }
    }
  }

  boolean justCrossedGoalLine(Goal g) {
    float goalLineY = g.y + g.h;
    return (prevY > goalLineY && y <= goalLineY);
  }

  void draw() {
    noStroke();
    fill(250);
    ellipse(x, y, r*2, r*2);
    fill(0, 40);
    ellipse(x - 3, y - 2, 5, 5);
    ellipse(x + 4, y + 3, 5, 5);
  }
}

class Goalkeeper {
  float x, y;
  float minX, maxX;

  float baseSpeed = 3.2;

  // Commit once per shot
  boolean committed = false;
  float committedTargetX = 0;

  // Dive animation
  int diveDir = 0;          // -1 left, 0 center, +1 right
  float diveT = 0;          // 0..1 animation progress
  float diveRot = 0;        // rotation angle for body (radians)

  Goalkeeper(float x, float y, float minX, float maxX) {
    this.x = x;
    this.y = y;
    this.minX = minX;
    this.maxX = maxX;
    committedTargetX = x;
  }

  void reset() {
    x = (minX + maxX) * 0.5;
    committed = false;
    committedTargetX = x;
    diveDir = 0;
    diveT = 0;
    diveRot = 0;
  }

  void commitToShot(Ball b, Goal g, float errorRange) {
    float error = random(-errorRange, errorRange);
    committedTargetX = constrain(b.x + error, minX, maxX);
    committed = true;

    // Decide dive direction by comparing committed target to current x
    float dx = committedTargetX - x;
    if (abs(dx) < 18) diveDir = 0;
    else diveDir = (dx < 0) ? -1 : 1;

    diveT = 0;
  }

  void update(int state, Ball b, Goal g) {
    float targetX;

    if (state == STATE_AIM) {
      targetX = (minX + maxX) * 0.5 + sin(frameCount * 0.05) * 40;
      committed = false; // don't keep commitment between shots
      diveDir = 0;
      diveT = 0;
      diveRot = 0;
    } else if (state == STATE_SHOOTING) {
      targetX = committed ? committedTargetX : x;

      // progress dive animation while shooting
      diveT = min(1.0, diveT + 0.06);
      diveRot = diveDir * lerp(0.0, radians(55), easeOut(diveT));
    } else {
      targetX = x;

      // keep pose in RESULT state (freeze)
      if (state == STATE_RESULT) {
        diveT = 1.0;
      }
    }

    float spd = (state == STATE_SHOOTING) ? baseSpeed : baseSpeed * 0.6;
    x = lerp(x, targetX, 0.06 * spd);
    x = constrain(x, minX, maxX);
  }

  float easeOut(float t) {
    // quick easing function for nicer motion
    return 1 - pow(1 - t, 3);
  }

  void draw() {
    rectMode(CENTER);

    // Body transform (dive animation)
    pushMatrix();
    translate(x, y);

    // shift body sideways and slightly down when diving
    float shiftX = diveDir * 28 * easeOut(diveT);
    float shiftY = 10 * easeOut(diveT);
    translate(shiftX, shiftY);

    // rotate body
    rotate(diveRot);

    // body
    noStroke();
    fill(20, 60, 200);
    rect(0, 0, 36, 26, 6);

    // head
    fill(240, 200, 160);
    ellipse(0, -20, 18, 18);

    // arms/gloves (extend more during dive)
    fill(255);
    float armReach = 22 + 12 * easeOut(diveT);
    ellipse(-armReach, 0, 10, 10);
    ellipse(armReach, 0, 10, 10);

    popMatrix();

    // Optional ring indicator
    if (committed) {
      noFill();
      stroke(255, 160);
      strokeWeight(2);
      ellipse(x, y, 48, 44);
    }

    rectMode(CORNER);
  }
}

class Goal {
  float x, y, w, h;

  Goal(float x, float y, float w, float h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  void draw() {
    noStroke();
    fill(255, 255, 255, 40);
    rect(x, y, w, h);

    stroke(255);
    strokeWeight(5);
    noFill();
    rect(x, y, w, h);

    stroke(255, 70);
    strokeWeight(1);
    for (int i = 0; i <= 10; i++) {
      float xx = lerp(x, x + w, i/10.0);
      line(xx, y, xx, y + h);
    }
    for (int j = 0; j <= 6; j++) {
      float yy = lerp(y, y + h, j/6.0);
      line(x, yy, x + w, yy);
    }
  }

  boolean containsX(float px) {
    return px >= x && px <= x + w;
  }
}
