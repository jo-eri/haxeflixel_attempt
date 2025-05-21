package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

// PlayerSprite class - handles the actual player character sprite and movement
class PlayerSprite extends FlxSprite {
    // Constants for player movement and abilities
    static inline var BASE_SPEED:Float = 150;
    static inline var MAX_SPEED:Float = 300;
    static inline var ACCEL:Float = 1200;
    static inline var DRAG:Float = 800;
    static inline var SPRINT_MULT:Float = 1.8; // Multiplier for acceleration when sprinting
    static inline var SPRINT_DRAIN:Float = 25;
    static inline var DIRECTION_CHANGE_BOOST:Float = 1.3; // Boost to acceleration when changing direction

    // Jump properties
    static inline var JUMP_IMPULSE:Float = 350;
    static inline var JUMP_COOLDOWN:Float = 0.5;
    static inline var JUMP_COST:Float = 35;

    // Runtime properties
    public var isJumping:Bool = false;
    public var jumpCooldownTimer:Float = 0;
    public var attackCooldownTimer:Float = 0;
    public var iframeTimer:Float = 0;
    public var lastMoveDir:FlxPoint;
    public var manaRegenRate:Float = 5; // Mana per second
    public var healthRegenRate:Float = 1; // Health per second

    // Dash properties
    private var dashDuration:Float = 0.15; // How long the dash lasts
    private var dashTimer:Float = 0;       // Current dash timer
    private var dashSpeed:Float = 1000;     // Dash speed
    private var dashDirection:FlxPoint;    // Store dash direction

    // For direction change detection
    private var prevMoveX:Float = 0;
    private var prevMoveY:Float = 0;

    // Reference to parent
    private var playerRef(get, never):Player;

    private function get_playerRef():Player {
        // This is a common pattern to get a reference to the parent group or state,
        // but be mindful of performance in very large games.
        // For a core vertical slice, this is usually fine.
        for (member in FlxG.state.members) {
            if (Std.isOfType(member, Player)) {
                return cast member;
            }
        }
        return null; // Should not happen if Player is added to state
    }

    public function new(x:Float=0, y:Float=0) {
        super(x, y);
        makeGraphic(16, 16, FlxColor.WHITE);

        // Smooth movement
        acceleration.set(0, 0);
        drag.set(DRAG, DRAG);
        maxVelocity.set(MAX_SPEED, MAX_SPEED);

        lastMoveDir = new FlxPoint(0, 1); // Default facing down
        dashDirection = new FlxPoint(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        // Update timers
        if (jumpCooldownTimer > 0) jumpCooldownTimer -= elapsed;
        if (attackCooldownTimer > 0) attackCooldownTimer -= elapsed;
        if (iframeTimer > 0) updateIframes(elapsed);

        // Mouse aiming
        var mousePos = FlxG.mouse.getPosition();
        angle = FlxAngle.angleBetweenMouse(this, true);

        // Only process movement input when not dashing
        if (dashTimer <= 0) {
            handleMovement(elapsed);
        }

        // Jump/dash logic - always process this
        handleJump(elapsed);
    }

    private function handleMovement(elapsed:Float):Void {
        // Check if playerRef is null before accessing its properties
        if (playerRef == null || playerRef.isDead) return; // Do not move if player is dead

        // Check if playerRef is blocking
        if (playerRef.isBlocking) {
            // Reduced movement while blocking
            acceleration.set(0, 0);
            drag.set(DRAG * 2, DRAG * 2); // Higher drag while blocking
            return;
        }

        // Get input
        var moveX:Float = (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A ? -1 : 0) + (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D ? 1 : 0);
        var moveY:Float = (FlxG.keys.pressed.UP || FlxG.keys.pressed.W ? -1 : 0) + (FlxG.keys.pressed.DOWN || FlxG.keys.pressed.S ? 1 : 0);

        var moving:Bool = (moveX != 0 || moveY != 0);

        if (moving) {
            // Normalize direction
            var len:Float = Math.sqrt(moveX * moveX + moveY * moveY);
            if (len > 0) { // Avoid division by zero
                moveX /= len;
                moveY /= len;
            }

            // Update last direction only if actually moving
            lastMoveDir.set(moveX, moveY);

            var currentAccel = ACCEL;
            var currentMaxSpeed = BASE_SPEED;

            if (FlxG.keys.pressed.SHIFT && playerRef.stamina > 0) {
                // Sprinting: increase acceleration and max speed
                currentAccel *= SPRINT_MULT;
                currentMaxSpeed = MAX_SPEED;
                playerRef.stamina -= SPRINT_DRAIN * elapsed;
            }

            // Apply direction change boost if changing direction quickly
            if ((moveX != 0 && Math.abs(prevMoveX + moveX) < 0.1) || (moveY != 0 && Math.abs(prevMoveY + moveY) < 0.1)) {
                currentAccel *= DIRECTION_CHANGE_BOOST;
            }

            acceleration.set(moveX * currentAccel, moveY * currentAccel);
            maxVelocity.set(currentMaxSpeed, currentMaxSpeed);
        } else {
            acceleration.set(0, 0);
            maxVelocity.set(BASE_SPEED, BASE_SPEED); // Reset max speed when not moving
        }

        // Set normal drag when not blocking
        drag.set(DRAG, DRAG);

        // Store current movement for next frame
        prevMoveX = moveX;
        prevMoveY = moveY;
    }

    private function handleJump(elapsed:Float):Void {
        if (playerRef == null || playerRef.isDead) return; // Do not jump if player is dead

        // Start a new dash
        if (FlxG.keys.justPressed.SPACE && playerRef.stamina >= JUMP_COST && jumpCooldownTimer <= 0 && !isJumping) {
            // Determine dash direction based on input, not current velocity
            var moveX:Float = (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A ? -1 : 0) +
                             (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D ? 1 : 0);
            var moveY:Float = (FlxG.keys.pressed.UP || FlxG.keys.pressed.W ? -1 : 0) +
                             (FlxG.keys.pressed.DOWN || FlxG.keys.pressed.S ? 1 : 0);

            // If no input, use last movement direction
            if (moveX == 0 && moveY == 0) {
                moveX = lastMoveDir.x;
                moveY = lastMoveDir.y;
            }

            // Store normalized dash direction
            dashDirection = new FlxPoint(moveX, moveY);
            if (moveX != 0 || moveY != 0) {
                dashDirection.normalize();
            } else {
                // If still no direction (e.g., player was idle and no lastMoveDir was set),
                // default to facing forward (downwards)
                dashDirection.set(0, 1);
            }

            // Initialize dash
            dashTimer = dashDuration;
            isJumping = true; // Use isJumping to denote being in a special movement state (dash/iframe)
            playerRef.stamina -= JUMP_COST;
            jumpCooldownTimer = JUMP_COOLDOWN;
            iframeTimer = dashDuration + 0.1; // Slightly longer iframes than dash duration

            // Visual feedback
            alpha = 0.5;

            // Optional: add a dash effect
            // FlxG.sound.play("assets/sounds/dash.wav");
        }

        // Update ongoing dash
        if (dashTimer > 0) {
            // During dash, override normal movement controls
            dashTimer -= elapsed;

            // Apply dash velocity directly
            velocity.x = dashDirection.x * dashSpeed;
            velocity.y = dashDirection.y * dashSpeed;

            // Optional: create motion trail
            if (FlxG.random.float() < 0.3) {
                var trail = new FlxSprite(x, y);
                trail.makeGraphic(Std.int(width), Std.int(height), FlxColor.WHITE);
                trail.alpha = 0.3;
                trail.angle = angle;
                (cast FlxG.state).add(trail); // Add to state for proper rendering/cleanup
                FlxTween.tween(trail, {alpha: 0}, 0.2, {onComplete: function(_) {
                    (cast FlxG.state).remove(trail, true);
                    trail.destroy();
                }});
            }

            // End of dash
            if (dashTimer <= 0) {
                // Apply a small amount of carried momentum
                velocity.x = dashDirection.x * (MAX_SPEED * 0.8);
                velocity.y = dashDirection.y * (MAX_SPEED * 0.8);
            }
        }
    }

    private function updateIframes(elapsed:Float):Void {
        iframeTimer -= elapsed;
        if (iframeTimer <= 0) {
            isJumping = false; // Reset jump state when iframes end
            alpha = 1; // Restore full opacity
        }
    }
}
