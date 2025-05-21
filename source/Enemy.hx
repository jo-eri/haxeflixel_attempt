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
            if (!sprite.exists || !exists) {
                return;
            }
        }

        healthBar.x = sprite.x + sprite.width / 2 - healthBar.width / 2;
        healthBar.y = sprite.y - 10;
        rankText.x = sprite.x + sprite.width / 2 - rankText.width / 2;
        rankText.y = healthBar.y - 10;

        if (attackTimer > 0) attackTimer -= elapsed;
        if (patrolTimer > 0) patrolTimer -= elapsed;
        if (stunTimer > 0) stunTimer -= elapsed; 
        if (iframeTimer > 0) iframeTimer -= elapsed;

        switch (currentState) {
            case STATE_IDLE: handleIdleState(elapsed);
            case STATE_PATROL: handlePatrolState(elapsed);
            case STATE_CHASE: handleChaseState(elapsed);
            case STATE_ATTACK: handleAttackState(elapsed);
            case STATE_STUNNED: handleStunnedState(elapsed);
            case STATE_DEAD: // Do nothing
        }

        if (telegraphSprite != null && telegraphSprite.alpha > 0) {
            telegraphSprite.setPosition(
                sprite.x + sprite.width/2 - telegraphSprite.width/2,
                sprite.y + sprite.height/2 - telegraphSprite.height/2
            );
        }
    }

    private function handleIdleState(elapsed:Float):Void {
        if (player != null && !player.isDead && FlxMath.distanceBetween(sprite, player.sprite) < 150) {
            currentState = STATE_CHASE;
        }
    }

    private function handlePatrolState(elapsed:Float):Void {
        if (patrolTimer <= 0) {
            var angle = FlxG.random.float(0, 360) * (Math.PI / 180);
            sprite.velocity.x = Math.cos(angle) * speed;
            sprite.velocity.y = Math.sin(angle) * speed;
            patrolTimer = FlxG.random.float(1, 3);
        }
        if (player != null && !player.isDead && FlxMath.distanceBetween(sprite, player.sprite) < 100) {
            currentState = STATE_CHASE;
        }
    }

    private function handleChaseState(elapsed:Float):Void {
        if (player == null || player.isDead) { 
            sprite.velocity.set(0, 0);
            currentState = STATE_IDLE; 
            return;
        }
        var distanceToPlayer:Float = FlxMath.distanceBetween(sprite, player.sprite);
        if (distanceToPlayer <= attackRange) {
            currentState = STATE_ATTACK;
            sprite.velocity.set(0,0); 
        } else {
            FlxVelocity.moveTowardsObject(sprite, player.sprite, speed); 
        }
    }

    private function handleAttackState(elapsed:Float):Void {
        if (player == null || player.isDead) { 
            isWindingUpAttack = false;
            if (telegraphSprite != null) telegraphSprite.alpha = 0;
            currentState = STATE_IDLE; 
            return;
        }
        sprite.velocity.set(0, 0);
        var distanceToPlayer:Float = FlxMath.distanceBetween(sprite, player.sprite);
        if (distanceToPlayer > attackRange * 1.5) { 
            isWindingUpAttack = false;
            if (telegraphSprite != null) telegraphSprite.alpha = 0;
            currentState = STATE_CHASE;
            return;
        }
        if (!isWindingUpAttack && attackTimer <= 0) {
            isWindingUpAttack = true;
            attackWindupTimer = 0.5; 
            attackDirection = new FlxPoint(player.sprite.x - sprite.x, player.sprite.y - sprite.y);
            attackDirection.normalize();
            if (telegraphSprite != null) {
                telegraphSprite.setPosition(
                    sprite.x + sprite.width/2 - telegraphSprite.width/2,
                    sprite.y + sprite.height/2 - telegraphSprite.height/2
                );
                FlxTween.tween(telegraphSprite, {alpha: 0.3}, 0.2); 
            }
        } else if (isWindingUpAttack) {
            attackWindupTimer -= elapsed;
            if (telegraphSprite != null) {
                telegraphSprite.setPosition(
                    sprite.x + sprite.width/2 - telegraphSprite.width/2,
                    sprite.y + sprite.height/2 - telegraphSprite.height/2
                );
            }
            if (attackWindupTimer <= 0) {
                performAttack();
                isWindingUpAttack = false;
                if (telegraphSprite != null) telegraphSprite.alpha = 0; 
                attackTimer = attackCooldown; 
                currentState = STATE_CHASE; 
            }
        }
    }

    private function handleStunnedState(elapsed:Float):Void {
        sprite.velocity.set(0, 0); 
        if (stunTimer <= 0) {
            if (!isDead && currentState == STATE_STUNNED) { 
                 currentState = STATE_CHASE; 
            }
        }
    }

    private function performAttack():Void {
        if (player == null || player.isDead) return;
        var lungeDistance = 40 + (enemyRank * 10);
        var lungeSpeed = 400 + (enemyRank * 50);
        if (attackDirection == null) {
            attackDirection = new FlxPoint(player.sprite.x - sprite.x, player.sprite.y - sprite.y);
            attackDirection.normalize();
        }
        sprite.velocity.x = attackDirection.x * lungeSpeed;
        sprite.velocity.y = attackDirection.y * lungeSpeed;
        FlxTween.tween(sprite, {alpha: 0.5}, 0.1).then(FlxTween.tween(sprite, {alpha: 1.0}, 0.1));
        new FlxTimer().start(lungeDistance / lungeSpeed, function(_) {
            sprite.velocity.set(0, 0);
        });
        new FlxTimer().start(0.1, function(_) { 
            if (player != null && !player.isDead) {
                var newDistanceToPlayer = FlxMath.distanceBetween(sprite, player.sprite);
                if (newDistanceToPlayer <= attackRange * 1.2) { 
                    player.takeDamage(calculateDamage(), this); // MODIFIED LINE
                }
            }
        });
    }

    public function takeDamage(amount:Float, knockback:Float = 0, isCritical:Bool = false):Void {
        if (isDead || iframeTimer > 0) return;
        var damageReduction:Float = defense / (defense + 100); 
        var reducedDamage:Float = amount * (1 - damageReduction);
        if (reducedDamage < 1) reducedDamage = 1;
        health -= reducedDamage;
        if (!flashingHealthBar) {
            flashingHealthBar = true;
            healthBar.createFilledBar(FlxColor.fromRGB(80, 80, 80), FlxColor.WHITE); 
            new FlxTimer().start(0.2, function(_) {
                flashingHealthBar = false;
                healthBar.createFilledBar(FlxColor.fromRGB(80, 80, 80), healthBarDefaultColor); 
            });
        }
        showDamageNumber(Math.ceil(reducedDamage), isCritical);
        if (knockback > 0 && player != null) {
            var knockbackDirection:FlxPoint = new FlxPoint(sprite.x - player.sprite.x, sprite.y - player.sprite.y);
            if (knockbackDirection.length > 0) knockbackDirection.normalize();
            else knockbackDirection.set(FlxG.random.float(-1, 1), FlxG.random.float(-1, 1)).normalize();
            sprite.velocity.x = knockbackDirection.x * knockback;
            sprite.velocity.y = knockbackDirection.y * knockback;
            
            // Apply stun when knocked back by player damage
            stun(0.3); // Call the new stun method

        }
        FlxFlicker.flicker(sprite, 0.2, 0.04);
        iframeTimer = 0.3; 
        if (health <= 0) {
            die();
        }
    }

    private function showDamageNumber(damage:Int, isCritical:Bool = false):Void {
        var damageText:FlxText = new FlxText(
            sprite.x + FlxG.random.float(0, sprite.width),
            sprite.y + FlxG.random.float(0, sprite.height / 2),0, Std.string(damage) );
        if (isCritical) {
            damageText.setFormat(null, 16, FlxColor.YELLOW, "center"); 
            damageText.text = "CRIT! " + damageText.text; 
        } else {
            damageText.setFormat(null, 12, FlxColor.WHITE);
        }
        (cast FlxG.state).add(damageText);
        FlxTween.tween(damageText, {y: damageText.y - 20, alpha: 0}, 0.5, {
            onComplete: function(_) {
                (cast FlxG.state).remove(damageText);
                damageText.destroy();
            }
        });
    }

    public function calculateDamage(isPhysical:Bool = true, baseDamage:Float = -1):Float {
        var damage:Float;
        if (baseDamage < 0) damage = attackPower;
        else damage = baseDamage;
        return damage;
    }

    public function stun(duration:Float):Void {
        if (isDead || currentState == STATE_STUNNED) { return; }
        currentState = STATE_STUNNED;
        stunTimer = duration;
        sprite.velocity.set(0, 0); 
        if (isWindingUpAttack) {
            isWindingUpAttack = false;
            if (telegraphSprite != null) { telegraphSprite.alpha = 0; }
        }
        FlxFlicker.flicker(sprite, duration, 0.06, false, function(_){
            if (stunTimer <= 0 && !isDead && currentState == STATE_STUNNED) {
                 currentState = STATE_CHASE; 
            }
        });
        FlxG.log.add('Enemy stunned for ' + duration + 's');
    }

    private function die():Void {
        isDead = true;
        health = 0;
        currentState = STATE_DEAD;
        sprite.velocity.set(0, 0);
        createDeathEffect();
        FlxTween.tween(sprite, {alpha: 0, scale: {x: 0.5, y: 0.5}}, 0.5, {
            onComplete: function(_) {
                if (player != null) player.gainExperience(experienceValue);
                dropLoot();
                if (telegraphSprite != null) {
                    telegraphSprite.alpha = 0;
                    (cast FlxG.state).remove(telegraphSprite);
                    telegraphSprite.destroy();
                }
                exists = false; 
                destroy();
            }
        });
        healthBar.visible = false;
        rankText.visible = false;
    }

    private function createDeathEffect():Void {
        for (i in 0...15) { 
            var particle = new FlxSprite(
                sprite.x + sprite.width/2 + FlxG.random.float(-5, 5),
                sprite.y + sprite.height/2 + FlxG.random.float(-5, 5) );
            particle.makeGraphic(4, 4, sprite.color); 
            var angle = FlxG.random.float(0, 360) * (Math.PI / 180);
            var speed = FlxG.random.float(80, 150); 
            particle.velocity.x = Math.cos(angle) * speed; 
            particle.velocity.y = Math.sin(angle) * speed; 
            (cast FlxG.state).add(particle);
            FlxTween.tween(particle, {alpha: 0, scale: {x: 0.2, y: 0.2}}, 0.5 + FlxG.random.float(0, 0.2), {
                onComplete: function(_) {
                    (cast FlxG.state).remove(particle);
                    particle.destroy();
                }
            });
        }
    }

    private function dropLoot():Void {
        FlxG.log.add("Enemy " + getRankString(enemyRank) + " killed! Loot dropped (placeholder).");
    }

    override public function destroy():Void {
        super.destroy();
        if (healthBar != null) healthBar.destroy();
        if (rankText != null) rankText.destroy();
        if (telegraphSprite != null) telegraphSprite.destroy();
    }
}
