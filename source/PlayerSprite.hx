package source;

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
import source.PlayState; // Import PlayState to access enemyGroup
import source.Enemy;    // Import Enemy for type checking

// PlayerSprite class - handles the actual player character sprite and movement
class PlayerSprite extends FlxSprite {
    // Constants for player movement and abilities
    static inline var BASE_SPEED:Float = 150;
    static inline var MAX_SPEED:Float = 300;
    static inline var ACCEL:Float = 1200;
    static inline var DRAG:Float = 800;
    static inline var SPRINT_MULT:Float = 1.8; 
    static inline var SPRINT_DRAIN:Float = 25;
    static inline var DIRECTION_CHANGE_BOOST:Float = 1.3;

    static inline var JUMP_IMPULSE:Float = 350;
    static inline var JUMP_COOLDOWN:Float = 0.5;
    static inline var JUMP_COST:Float = 35;

    public var isJumping:Bool = false;
    public var jumpCooldownTimer:Float = 0;
    public var attackCooldownTimer:Float = 0;
    public var iframeTimer:Float = 0;
    public var lastMoveDir:FlxPoint;
    public var manaRegenRate:Float = 5; 
    public var healthRegenRate:Float = 1;

    private var dashDuration:Float = 0.15; 
    private var dashTimer:Float = 0;       
    private var dashSpeed:Float = 1000;    
    private var dashDirection:FlxPoint;    

    private var prevMoveX:Float = 0;
    private var prevMoveY:Float = 0;

    private var playerRef(get, never):Player;

    private function get_playerRef():Player {
        for (member in FlxG.state.members) {
            if (Std.isOfType(member, Player)) {
                return cast member;
            }
        }
        return null; 
    }

    public function new(x:Float=0, y:Float=0) {
        super(x, y);
        makeGraphic(16, 16, FlxColor.WHITE);
        acceleration.set(0, 0);
        drag.set(DRAG, DRAG);
        maxVelocity.set(MAX_SPEED, MAX_SPEED);
        lastMoveDir = new FlxPoint(0, 1); 
        dashDirection = new FlxPoint(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (jumpCooldownTimer > 0) jumpCooldownTimer -= elapsed;
        if (attackCooldownTimer > 0) attackCooldownTimer -= elapsed;
        
        if (iframeTimer > 0) {
            updateIframes(elapsed);
        } else if (isJumping) { 
            isJumping = false;
            alpha = 1;
        }

        var mousePos = FlxG.mouse.getPosition();
        angle = FlxAngle.angleBetweenMouse(this, true);

        if (dashTimer <= 0) {
            handleMovement(elapsed);
        }

        handleJump(elapsed); 
    }

    private function handleMovement(elapsed:Float):Void {
        if (playerRef == null || playerRef.isDead) return;
        if (playerRef.isBlocking) {
            acceleration.set(0, 0);
            drag.set(DRAG * 2, DRAG * 2); 
            return;
        }

        var moveX:Float = (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A ? -1 : 0) + (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D ? 1 : 0);
        var moveY:Float = (FlxG.keys.pressed.UP || FlxG.keys.pressed.W ? -1 : 0) + (FlxG.keys.pressed.DOWN || FlxG.keys.pressed.S ? 1 : 0);
        var moving:Bool = (moveX != 0 || moveY != 0);

        if (moving) {
            var len:Float = Math.sqrt(moveX * moveX + moveY * moveY);
            if (len > 0) { 
                moveX /= len;
                moveY /= len;
            }
            lastMoveDir.set(moveX, moveY);
            var currentAccel = ACCEL;
            var currentMaxSpeed = BASE_SPEED;
            if (FlxG.keys.pressed.SHIFT && playerRef.stamina > 0) {
                currentAccel *= SPRINT_MULT;
                currentMaxSpeed = MAX_SPEED;
                playerRef.stamina -= SPRINT_DRAIN * elapsed;
            }
            if ((moveX != 0 && Math.abs(prevMoveX + moveX) < 0.1) || (moveY != 0 && Math.abs(prevMoveY + moveY) < 0.1)) {
                currentAccel *= DIRECTION_CHANGE_BOOST;
            }
            acceleration.set(moveX * currentAccel, moveY * currentAccel);
            maxVelocity.set(currentMaxSpeed, currentMaxSpeed);
        } else {
            acceleration.set(0, 0);
            maxVelocity.set(BASE_SPEED, BASE_SPEED); 
        }
        drag.set(DRAG, DRAG);
        prevMoveX = moveX;
        prevMoveY = moveY;
    }

    private function handleJump(elapsed:Float):Void { // This is actually the dash function
        if (playerRef == null || playerRef.isDead) return; 

        if (FlxG.keys.justPressed.SPACE && playerRef.stamina >= JUMP_COST && jumpCooldownTimer <= 0 && !isJumping) {
            
            // --- Start of Close Dodge Logic (Re-implementation attempt) ---
            var playState = cast(FlxG.state, PlayState);
            if (playState != null && playState.enemyGroup != null) {
                var closeDodgeRange = this.width * 3; // Increased range slightly
                for (enemy in playState.enemyGroup.members) {
                    if (enemy != null && enemy.exists && enemy.alive && !enemy.isDead) {
                        var enemySprite = enemy.sprite; 
                        if (enemySprite != null && FlxMath.distanceBetween(this, enemySprite) < closeDodgeRange) {
                            playerRef.stamina += JUMP_COST / 2;
                            if (playerRef.stamina > playerRef.maxStamina) {
                                playerRef.stamina = playerRef.maxStamina;
                            }
                            FlxG.log.add("Close Dodge! Stamina refunded.");
                            var originalColor = this.color;
                            this.color = FlxColor.LIME; // Changed color for distinction
                            new FlxTimer().start(0.1, function(tmr:FlxTimer) { this.color = originalColor; });
                            break; 
                        }
                    }
                }
            }
            // --- End of Close Dodge Logic ---

            var moveX:Float = (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A ? -1 : 0) +
                             (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D ? 1 : 0);
            var moveY:Float = (FlxG.keys.pressed.UP || FlxG.keys.pressed.W ? -1 : 0) +
                             (FlxG.keys.pressed.DOWN || FlxG.keys.pressed.S ? 1 : 0);
            if (moveX == 0 && moveY == 0) {
                moveX = lastMoveDir.x;
                moveY = lastMoveDir.y;
            }
            dashDirection = new FlxPoint(moveX, moveY); // dashDirection is used for dust particles
            if (moveX != 0 || moveY != 0) {
                dashDirection.normalize();
            } else {
                dashDirection.set(0, 1); // Default dash direction if no input
            }
            
            // --- Dust Cloud Effect ---
            var numDustParticles = FlxG.random.int(3, 5);
            for (i in 0...numDustParticles) {
                var dustParticle = new FlxSprite(this.x + this.width / 2, this.y + this.height - 4);
                dustParticle.makeGraphic(FlxG.random.int(2, 4), FlxG.random.int(2, 4), FlxColor.GRAY);
                dustParticle.alpha = FlxG.random.float(0.5, 0.8);
                // Velocity opposite to dash direction, plus some randomness and upward motion
                var dustVelX = -dashDirection.x * FlxG.random.float(20, 50) + FlxG.random.float(-20, 20);
                var dustVelY = -dashDirection.y * FlxG.random.float(20, 50) + FlxG.random.float(-30, -10); // More upward
                dustParticle.velocity.set(dustVelX, dustVelY);
                
                if (FlxG.state != null) (cast FlxG.state).add(dustParticle);

                FlxTween.tween(dustParticle, {alpha: 0, scale: {x:0.1, y:0.1}}, 0.3 + FlxG.random.float(0, 0.2), {
                    onComplete: function(tween:FlxTween) {
                        if (dustParticle != null) {
                           if (FlxG.state != null) (cast FlxG.state).remove(dustParticle, true);
                            dustParticle.destroy();
                        }
                    }
                });
            }
            // --- End Dust Cloud Effect ---

            dashTimer = dashDuration;
            isJumping = true; 
            playerRef.stamina -= JUMP_COST; 
            if(playerRef.stamina < 0) playerRef.stamina = 0; 

            jumpCooldownTimer = JUMP_COOLDOWN;
            iframeTimer = dashDuration + 0.1; 
            // No initial alpha = 0.5; updateIframes handles iframe visuals
        }

        if (dashTimer > 0) {
            dashTimer -= elapsed;
            velocity.x = dashDirection.x * dashSpeed;
            velocity.y = dashDirection.y * dashSpeed;
            // The existing motion trail logic
            if (FlxG.random.float() < 0.3) {
                var trail = new FlxSprite(x, y);
                trail.makeGraphic(Std.int(width), Std.int(height), FlxColor.WHITE);
                trail.alpha = 0.3;
                trail.angle = angle;
                (cast FlxG.state).add(trail); 
                FlxTween.tween(trail, {alpha: 0}, 0.2, {onComplete: function(_) {
                    (cast FlxG.state).remove(trail, true);
                    trail.destroy();
                }});
            }
            if (dashTimer <= 0) {
                velocity.x = dashDirection.x * (MAX_SPEED * 0.8);
                velocity.y = dashDirection.y * (MAX_SPEED * 0.8);
            }
        }
    }

    private function updateIframes(elapsed:Float):Void {
        iframeTimer -= elapsed;
        if (iframeTimer > 0) {
            if (isJumping) { 
                alpha = 0.5 + 0.2 * Math.sin( (dashDuration + 0.1 - iframeTimer) * 30 ); 
            }
        } else {
            if(isJumping) { 
                isJumping = false; 
            }
            alpha = 1; 
        }
    }
}
