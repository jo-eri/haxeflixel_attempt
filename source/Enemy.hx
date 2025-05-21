package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxVelocity; // Keep this for moveTowardsObject
import flixel.text.FlxText;
// import flixel.text.FlxTextBorderStyle; // Removed: Type not found
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

/**
 * Base class for all enemies in the game
 */
class Enemy extends FlxGroup {
    // Enemy types/ranks
    public static inline var RANK_E:Int = 1;
    public static inline var RANK_D:Int = 2;
    public static inline var RANK_C:Int = 3;
    public static inline var RANK_B:Int = 4;
    public static inline var RANK_A:Int = 5;
    public static inline var RANK_S:Int = 6;

    // Enemy behavior states
    public static inline var STATE_IDLE:Int = 0;
    public static inline var STATE_PATROL:Int = 1;
    public static inline var STATE_CHASE:Int = 2;
    public static inline var STATE_ATTACK:Int = 3;
    public static inline var STATE_STUNNED:Int = 4;
    public static inline var STATE_DEAD:Int = 5;

    // Base enemy stats - will be modified based on rank
    public var maxHealth:Float = 50;
    public var health:Float = 50;
    public var attackPower:Float = 10;
    public var defense:Float = 5;
    public var speed:Float = 80;
    public var attackRange:Float = 50;
    public var attackCooldown:Float = 1.5;
    public var experienceValue:Float = 20; // XP player gets on defeat

    public var enemyRank:Int; // To store the assigned rank

    // Enemy sprite
    public var sprite:FlxSprite;

    // UI elements
    private var healthBar:FlxBar;
    private var rankText:FlxText;

    // State machine variables
    public var currentState:Int = STATE_IDLE;
    private var attackTimer:Float = 0;
    private var patrolTimer:Float = 0;
    private var stunTimer:Float = 0;

    // Death state
    public var isDead:Bool = false;

    // Invincibility frames
    public var iframeTimer:Float = 0;

    // Reference to the player
    private var player:Player;

    // New properties for attack telegraphing
    private var attackWindupTimer:Float = 0;
    private var isWindingUpAttack:Bool = false;
    private var attackDirection:FlxPoint;
    private var telegraphSprite:FlxSprite;

    // New properties for health bar flashing
    private var flashingHealthBar:Bool = false;
    private var healthBarDefaultColor:FlxColor; // Store the original fill color

    public function new(x:Float, y:Float, rank:Int, playerRef:Player) {
        super();

        player = playerRef; // Store player reference
        enemyRank = rank;

        // Initialize sprite and set up basic visuals based on rank
        sprite = new FlxSprite(x, y);
        add(sprite); // Add sprite to group first

        setupSprite(); // Call setupSprite AFTER sprite is created and added

        // Initialize health bar and rank text
        createUI();

        // Adjust stats based on rank
        adjustStatsForRank();

        // Initial state
        currentState = STATE_CHASE; // Start chasing player for now
    }

    private function setupSprite():Void {
        // Base size and color vary by rank
        var size = 24 + (enemyRank - 1) * 4; // Size increases with rank, larger step
        var baseColor:FlxColor;

        switch (enemyRank) {
            case RANK_E:
                baseColor = FlxColor.fromRGB(200, 100, 100); // Light red
            case RANK_D:
                baseColor = FlxColor.fromRGB(200, 150, 100); // Orange-ish
            case RANK_C:
                baseColor = FlxColor.fromRGB(200, 200, 100); // Yellow-ish
            case RANK_B:
                baseColor = FlxColor.fromRGB(150, 200, 100); // Green-ish
            case RANK_A:
                baseColor = FlxColor.fromRGB(100, 150, 200); // Blue-ish
            case RANK_S:
                baseColor = FlxColor.fromRGB(150, 100, 200); // Purple-ish
            default:
                baseColor = FlxColor.RED;
        }

        sprite.makeGraphic(size, size, baseColor);
        sprite.centerOffsets(); // Center the sprite's origin for rotation etc.

        // Store healthbar default color
        healthBarDefaultColor = FlxColor.fromRGB(200, 50, 50);

        // Create telegraph sprite for attack warning (initially invisible)
        telegraphSprite = new FlxSprite(sprite.x, sprite.y);
        telegraphSprite.makeGraphic(Std.int(size * 1.5), Std.int(size * 1.5), FlxColor.RED);
        telegraphSprite.alpha = 0;
        telegraphSprite.centerOffsets();
        (cast FlxG.state).add(telegraphSprite); // Add to the state, not the enemy group, so it's always above
    }

    private function createUI():Void {
        // Health bar
        healthBar = new FlxBar(0, 0, LEFT_TO_RIGHT, Std.int(sprite.width * 0.8), 4, this, "health", 0, maxHealth);
        healthBar.createFilledBar(FlxColor.fromRGB(80, 80, 80), healthBarDefaultColor);
        healthBar.y = sprite.y - 10; // Position above the enemy
        healthBar.x = sprite.x + sprite.width / 2 - healthBar.width / 2;
        healthBar.screenCenter(X); // Center horizontally relative to sprite
        add(healthBar); // Add to this group

        // Rank text
        rankText = new FlxText(0, 0, 0, getRankString(enemyRank));
        rankText.setFormat(null, 8, FlxColor.WHITE, "center");
        rankText.y = healthBar.y - 10;
        rankText.x = sprite.x + sprite.width / 2 - rankText.width / 2;
        rankText.screenCenter(X); // Center horizontally relative to sprite
        add(rankText); // Add to this group
    }

    private function adjustStatsForRank():Void {
        var rankMultiplier = 1 + (enemyRank - 1) * 0.3; // Each rank adds 30% more power

        maxHealth *= rankMultiplier;
        health = maxHealth; // Start with full health
        attackPower *= rankMultiplier;
        defense *= rankMultiplier;
        speed *= rankMultiplier;
        attackRange *= 1 + (enemyRank - 1) * 0.05; // Slightly increased range for higher ranks
        attackCooldown /= (1 + (enemyRank - 1) * 0.05); // Faster attacks for higher ranks
        experienceValue *= rankMultiplier;

        healthBar.setRange(0, maxHealth); // Update health bar max value
    }

    private function getRankString(rank:Int):String {
        return switch(rank) {
            case RANK_E: "E";
            case RANK_D: "D";
            case RANK_C: "C";
            case RANK_B: "B";
            case RANK_A: "A";
            case RANK_S: "S";
            default: "?";
        };
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (isDead) {
            // If the sprite is already removed/destroyed, prevent further updates
            if (!sprite.exists || !exists) {
                return;
            }
        }

        // Update UI positions relative to the sprite
        healthBar.x = sprite.x + sprite.width / 2 - healthBar.width / 2;
        healthBar.y = sprite.y - 10;
        rankText.x = sprite.x + sprite.width / 2 - rankText.width / 2;
        rankText.y = healthBar.y - 10;

        // Update timers
        if (attackTimer > 0) attackTimer -= elapsed;
        if (patrolTimer > 0) patrolTimer -= elapsed;
        if (stunTimer > 0) stunTimer -= elapsed;
        if (iframeTimer > 0) iframeTimer -= elapsed;


        // State machine logic
        switch (currentState) {
            case STATE_IDLE:
                handleIdleState(elapsed);
            case STATE_PATROL:
                handlePatrolState(elapsed);
            case STATE_CHASE:
                handleChaseState(elapsed);
            case STATE_ATTACK:
                handleAttackState(elapsed);
            case STATE_STUNNED:
                handleStunnedState(elapsed);
            case STATE_DEAD:
                // Do nothing, object is dying/dead
        }

        // Update telegraph sprite position even if enemy is moving
        if (telegraphSprite != null && telegraphSprite.alpha > 0) {
            telegraphSprite.setPosition(
                sprite.x + sprite.width/2 - telegraphSprite.width/2,
                sprite.y + sprite.height/2 - telegraphSprite.height/2
            );
        }
    }

    private function handleIdleState(elapsed:Float):Void {
        // Maybe transition to patrol or chase if player is detected
        if (player != null && !player.isDead && FlxMath.distanceBetween(sprite, player.sprite) < 150) {
            currentState = STATE_CHASE;
        }
    }

    private function handlePatrolState(elapsed:Float):Void {
        // Simple patrol logic
        if (patrolTimer <= 0) {
            // Move in a random direction for a short duration
            var angle = FlxG.random.float(0, 360); // Angle in degrees
            // Convert angle to radians for sin/cos
            var radians = angle * (Math.PI / 180);
            sprite.velocity.x = Math.cos(radians) * speed;
            sprite.velocity.y = Math.sin(radians) * speed;
            patrolTimer = FlxG.random.float(1, 3);
        }

        // Transition to chase if player is near
        if (player != null && !player.isDead && FlxMath.distanceBetween(sprite, player.sprite) < 100) {
            currentState = STATE_CHASE;
        }
    }

    private function handleChaseState(elapsed:Float):Void {
        if (player == null || player.isDead) { // Stop chasing if player is dead
            sprite.velocity.set(0, 0);
            currentState = STATE_IDLE; // Go back to idle
            return;
        }

        var distanceToPlayer:Float = FlxMath.distanceBetween(sprite, player.sprite);

        if (distanceToPlayer <= attackRange) {
            currentState = STATE_ATTACK;
            sprite.velocity.set(0,0); // Stop moving when attacking
        } else {
            // Move towards the player using moveTowardsObject
            FlxVelocity.moveTowardsObject(sprite, player.sprite, speed); // Removed second speed arg, not needed
        }
    }

    /**
     * Handles enemy attack state with telegraphing and lunge.
     */
    private function handleAttackState(elapsed:Float):Void {
        if (player == null || player.isDead) { // Stop attacking if player is dead
            isWindingUpAttack = false;
            telegraphSprite.alpha = 0;
            currentState = STATE_IDLE; // Go back to idle
            return;
        }

        // Stop moving when attacking or winding up
        sprite.velocity.set(0, 0);

        var distanceToPlayer:Float = FlxMath.distanceBetween(sprite, player.sprite);

        if (distanceToPlayer > attackRange * 1.5) { // Increased range for player to move out of
            // Player moved out of attack range, disengage
            isWindingUpAttack = false;
            telegraphSprite.alpha = 0;
            currentState = STATE_CHASE;
            return;
        }

        if (!isWindingUpAttack && attackTimer <= 0) {
            // Start attack windup
            isWindingUpAttack = true;
            attackWindupTimer = 0.5; // Half second telegraph

            // Store attack direction at the beginning of windup
            attackDirection = new FlxPoint(
                player.sprite.x - sprite.x,
                player.sprite.y - sprite.y
            );
            attackDirection.normalize();

            // Show telegraph
            telegraphSprite.setPosition(
                sprite.x + sprite.width/2 - telegraphSprite.width/2,
                sprite.y + sprite.height/2 - telegraphSprite.height/2
            );
            FlxTween.tween(telegraphSprite, {alpha: 0.3}, 0.2); // Fade in telegraph
        } else if (isWindingUpAttack) {
            // During windup
            attackWindupTimer -= elapsed;

            // Keep telegraph centered on enemy
            telegraphSprite.setPosition(
                sprite.x + sprite.width/2 - telegraphSprite.width/2,
                sprite.y + sprite.height/2 - telegraphSprite.height/2
            );

            if (attackWindupTimer <= 0) {
                // Attack is ready, perform it
                performAttack();
                isWindingUpAttack = false;
                telegraphSprite.alpha = 0; // Hide telegraph
                attackTimer = attackCooldown; // Start attack cooldown
                currentState = STATE_CHASE; // Go back to chasing after attack
            }
        }
    }

    private function handleStunnedState(elapsed:Float):Void {
        sprite.velocity.set(0, 0); // Ensure enemy stops during stun
        stunTimer -= elapsed;
        if (stunTimer <= 0) {
            currentState = STATE_CHASE; // Or return to idle/patrol
        }
    }

    /**
     * Performs the enemy's attack, including a lunge movement.
     */
    private function performAttack():Void {
        if (player == null || player.isDead) return; // Don't attack if player is dead

        // Lunge toward player during attack (distance based on rank)
        var lungeDistance = 40 + (enemyRank * 10);
        var lungeSpeed = 400 + (enemyRank * 50);

        // Use the stored attack direction from windup
        // If attackDirection is null (e.g. if enemy was created in attack state), calculate it
        if (attackDirection == null) {
            attackDirection = new FlxPoint(
                player.sprite.x - sprite.x,
                player.sprite.y - sprite.y
            );
            attackDirection.normalize();
        }


        // Apply lunge velocity
        sprite.velocity.x = attackDirection.x * lungeSpeed;
        sprite.velocity.y = attackDirection.y * lungeSpeed;

        // Play attack animation (simple flicker for now)
        FlxTween.tween(sprite, {alpha: 0.5}, 0.1).then(
            FlxTween.tween(sprite, {alpha: 1.0}, 0.1)
        );

        // Stop lunge after short distance or duration
        new FlxTimer().start(lungeDistance / lungeSpeed, function(_) {
            sprite.velocity.set(0, 0);
        });

        // Deal damage to player if in range after lunge
        new FlxTimer().start(0.1, function(_) { // Small delay to allow lunge to move enemy
            if (player != null && !player.isDead) {
                var newDistanceToPlayer = FlxMath.distanceBetween(sprite, player.sprite);
                if (newDistanceToPlayer <= attackRange * 1.2) { // Slightly increased hit range after lunge
                    player.takeDamage(calculateDamage());
                }
            }
        });
    }

    /**
     * Handles enemy taking damage, with knockback, flashing health bar, and damage numbers.
     */
    public function takeDamage(amount:Float, knockback:Float = 0, isCritical:Bool = false):Void {
        if (isDead || iframeTimer > 0) return;

        // Calculate damage reduction from defense
        var damageReduction:Float = defense / (defense + 100); // More realistic defense scaling
        var reducedDamage:Float = amount * (1 - damageReduction);

        // Ensure minimum damage of 1
        if (reducedDamage < 1) reducedDamage = 1;

        // Apply damage
        health -= reducedDamage;

        // Flash health bar red/white
        if (!flashingHealthBar) {
            flashingHealthBar = true;
            healthBar.createFilledBar(FlxColor.fromRGB(80, 80, 80), FlxColor.WHITE); // Flash white
            new FlxTimer().start(0.2, function(_) {
                flashingHealthBar = false;
                healthBar.createFilledBar(FlxColor.fromRGB(80, 80, 80), healthBarDefaultColor); // Revert to original
            });
        }

        // Create damage number indicator
        showDamageNumber(Math.ceil(reducedDamage), isCritical);

        // Apply knockback if specified
        if (knockback > 0 && player != null) {
            var knockbackDirection:FlxPoint = new FlxPoint(
                sprite.x - player.sprite.x,
                sprite.y - player.sprite.y
            );
            if (knockbackDirection.length > 0) {
                knockbackDirection.normalize();
            } else {
                // If player is directly on top, push randomly
                knockbackDirection.set(FlxG.random.float(-1, 1), FlxG.random.float(-1, 1)).normalize();
            }

            sprite.velocity.x = knockbackDirection.x * knockback;
            sprite.velocity.y = knockbackDirection.y * knockback;

            // Enemy is briefly stunned by knockback
            stunTimer = 0.3; // Duration of stun
            currentState = STATE_STUNNED;
            isWindingUpAttack = false; // Interrupt any ongoing windup
            telegraphSprite.alpha = 0; // Hide telegraph
        }

        // Visual feedback
        FlxFlicker.flicker(sprite, 0.2, 0.04);
        iframeTimer = 0.3; // Short invulnerability after hit

        // Check for death
        if (health <= 0) {
            die();
        }
    }

    /**
     * Displays a floating damage number above the enemy.
     */
    private function showDamageNumber(damage:Int, isCritical:Bool = false):Void {
        var damageText:FlxText = new FlxText(
            sprite.x + FlxG.random.float(0, sprite.width),
            sprite.y + FlxG.random.float(0, sprite.height / 2),
            0,
            Std.string(damage)
        );

        // Different formatting for critical hits
        if (isCritical) {
            damageText.setFormat(null, 16, FlxColor.YELLOW, "center"); // Removed FlxTextBorderStyle.OUTLINE
            damageText.text = "CRIT! " + damageText.text; // Add "CRIT!" text
        } else {
            damageText.setFormat(null, 12, FlxColor.WHITE);
        }

        // Add to the state, not the enemy group, so it renders independently
        (cast FlxG.state).add(damageText);

        // Animate damage number floating up and fading
        FlxTween.tween(damageText, {y: damageText.y - 20, alpha: 0}, 0.5, {
            onComplete: function(_) {
                (cast FlxG.state).remove(damageText);
                damageText.destroy();
            }
        });
    }

    // Calculate final damage (for enemy's own attack)
    public function calculateDamage(isPhysical:Bool = true, baseDamage:Float = -1):Float {
        var damage:Float;

        if (baseDamage < 0) {
            damage = attackPower;
        } else {
            damage = baseDamage;
        }

        // Enemies could have critical hits too, but for simplicity, not implemented here.
        return damage;
    }

    /**
     * Handles enemy death, including particles, fade out, XP gain, and loot drop.
     */
    private function die():Void {
        isDead = true;
        health = 0;
        currentState = STATE_DEAD;

        // Stop all movement
        sprite.velocity.set(0, 0);

        // Create death particles
        createDeathEffect();

        // Death animation (fade out and shrink)
        FlxTween.tween(sprite, {alpha: 0, scale: {x: 0.5, y: 0.5}}, 0.5, {
            onComplete: function(_) {
                // Grant experience to player
                if (player != null) {
                    player.gainExperience(experienceValue);
                }

                // Drop loot (placeholder for now)
                dropLoot();

                // Clear telegraph if any
                if (telegraphSprite != null) {
                    telegraphSprite.alpha = 0;
                    (cast FlxG.state).remove(telegraphSprite);
                    telegraphSprite.destroy();
                }

                // Mark for removal from group and destroy
                exists = false; // This will cause it to be removed from FlxTypedGroup
                destroy();
            }
        });

        // Hide UI elements immediately
        healthBar.visible = false;
        rankText.visible = false;
    }

    /**
     * Creates a small explosion of particles when the enemy dies.
     */
    private function createDeathEffect():Void {
        for (i in 0...15) { // More particles for better effect
            var particle = new FlxSprite(
                sprite.x + sprite.width/2 + FlxG.random.float(-5, 5),
                sprite.y + sprite.height/2 + FlxG.random.float(-5, 5)
            );
            particle.makeGraphic(4, 4, sprite.color); // Particles match enemy color

            // Random direction and speed
            var angle = FlxG.random.float(0, 360) * (Math.PI / 180);
            var radians = angle * (Math.PI / 180); // Convert to radians
            var speed = FlxG.random.float(80, 150); // Faster particles
            particle.velocity.x = Math.cos(radians) * speed;
            particle.velocity.y = Math.sin(radians) * speed;

            // Add to the game state
            (cast FlxG.state).add(particle);

            // Fade out and shrink
            FlxTween.tween(particle, {alpha: 0, scale: {x: 0.2, y: 0.2}}, 0.5 + FlxG.random.float(0, 0.2), {
                onComplete: function(_) {
                    (cast FlxG.state).remove(particle);
                    particle.destroy();
                }
            });
        }
    }

    /**
     * Placeholder for loot dropping logic.
     */
    private function dropLoot():Void {
        // Implement actual loot dropping here later
        FlxG.log.add("Enemy " + getRankString(enemyRank) + " killed! Loot dropped (placeholder).");
    }

    override public function destroy():Void {
        super.destroy();
        // Ensure UI elements and telegraph sprite are destroyed if they haven't been removed already
        if (healthBar != null) healthBar.destroy();
        if (rankText != null) rankText.destroy();
        if (telegraphSprite != null) telegraphSprite.destroy();
        // sprite is already part of the group, so super.destroy() handles it.
    }
}
