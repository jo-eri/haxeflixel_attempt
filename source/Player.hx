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

class Player extends FlxGroup {
    // Constants for player movement and abilities
    static inline var BASE_SPEED:Float = 150;
    static inline var MAX_SPEED:Float = 300;
    static inline var ACCEL:Float = 1200;
    static inline var DRAG:Float = 800;
    static inline var SPRINT_MULT:Float = 1.8;
    static inline var SPRINT_DRAIN:Float = 25;
    static inline var DIRECTION_CHANGE_BOOST:Float = 1.3;

    // Jump properties
    static inline var JUMP_IMPULSE:Float = 350;
    static inline var JUMP_COOLDOWN:Float = 0.5;
    static inline var JUMP_COST:Float = 35;

    // Attack properties
    static inline var ATTACK_COOLDOWN:Float = 0.4;
    static inline var ATTACK_COST:Float = 15;
    static inline var ATTACK_RANGE:Float = 40; // Base distance from player for hitbox placement
    static inline var BASE_HITBOX_WIDTH:Float = 30; // Store initial width of hitbox
    static inline var BASE_HITBOX_HEIGHT:Float = 30; // Store initial height of hitbox


    // Block properties
    static inline var BLOCK_DRAIN:Float = 20; // Per second
    static inline var PARRY_WINDOW:Float = 0.15; // 150ms window for perfect parry

    // UI Constants
    private static inline var BAR_WIDTH:Int = 150;
    private static inline var BAR_HEIGHT:Int = 15;
    private static inline var BAR_PADDING:Int = 5;

    // Player sprite
    public var sprite:PlayerSprite;

    // Combat elements
    public var attackHitbox:FlxSprite;
    public var isBlocking:Bool = false;
    public var isParrying:Bool = false;
    public var parryTimer:Float = 0;

    // New visual feedback for attacks
    private var attackEffectSprite:FlxSprite;
    public var lastAttackTime:Float = 0;
    public var attackComboCount:Int = 0;
    public var attackComboTimer:Float = 0;
    public static inline var COMBO_WINDOW:Float = 1.0; // Time window for combos

    // UI Elements
    private var healthBar:FlxBar;
    private var manaBar:FlxBar;
    private var staminaBar:FlxBar;
    private var levelText:FlxText;
    private var expBar:FlxBar;

    // Player stats
    public var health:Float = 100;
    public var maxHealth:Float = 100;
    public var mana:Float = 50;
    public var maxMana:Float = 50;
    public var stamina:Float = 100;
    public var maxStamina:Float = 100;
    public var level:Int = 1;
    public var experience:Float = 0;
    public var experienceNeeded:Float = 100;

    // Base stats (all start at 10)
    public var intelligence:Int = 10;  // Increases mana, magic damage, magic defense
    public var strength:Int = 10;      // Increases physical attack, physical defense
    public var healthStat:Int = 10;    // Increases health pool, health regen
    public var agility:Int = 10;       // Increases speed, attack speed, crit chance
    public var perception:Int = 10;    // Affects visibility, projectile detection

    // Derived stats
    public var critChance:Float = 5;     // Base 5% + agility bonus
    public var attackPower:Float = 10;   // Base + strength bonus
    public var magicPower:Float = 5;     // Base + intelligence bonus
    public var physicalDefense:Float = 5; // Base + strength bonus
    public var magicDefense:Float = 5;    // Base + intelligence bonus

    // Skill points
    public var skillPoints:Int = 0;

    // Player death state
    public var isDead:Bool = false; // Added isDead property

    // Sound effects (commented out as per original)
    // private var attackSound:FlxSound;
    // private var hurtSound:FlxSound;
    // private var levelUpSound:FlxSound;

    public function new(x:Float=0, y:Float=0) {
        super();

        // Create player sprite
        sprite = new PlayerSprite(x, y);
        add(sprite);

        // Create attack hitbox (invisible until attack)
        attackHitbox = new FlxSprite(x, y);
        // Use the new BASE_HITBOX_ constants here for initial size
        attackHitbox.makeGraphic(Std.int(BASE_HITBOX_WIDTH), Std.int(BASE_HITBOX_HEIGHT), FlxColor.RED);
        attackHitbox.alpha = 0; // Invisible by default
        attackHitbox.exists = false; // Disabled until attack
        // Removed the problematic attackHitbox.scale.set(1, 1); line
        add(attackHitbox);

        // Create UI elements
        createUI();

        // Load sounds (commented out)
        // attackSound = FlxG.sound.load("assets/sounds/attack.wav");
        // hurtSound = FlxG.sound.load("assets/sounds/hurt.wav");
        // levelUpSound = FlxG.sound.load("assets/sounds/levelup.wav");

        // Calculate derived stats
        recalculateStats();
    }

    private function createUI():Void {
        // Health bar
        healthBar = new FlxBar(10, 10, LEFT_TO_RIGHT, BAR_WIDTH, BAR_HEIGHT, this, "health", 0, maxHealth);
        healthBar.createFilledBar(FlxColor.GRAY, FlxColor.RED);
        add(healthBar);

        // Label for health
        var healthText = new FlxText(healthBar.x + BAR_WIDTH + 5, healthBar.y, 100, "HP");
        healthText.setFormat(null, 12, FlxColor.WHITE);
        add(healthText);

        // Mana bar
        manaBar = new FlxBar(10, healthBar.y + healthBar.height + BAR_PADDING, LEFT_TO_RIGHT, BAR_WIDTH, BAR_HEIGHT, this, "mana", 0, maxMana);
        manaBar.createFilledBar(FlxColor.GRAY, FlxColor.BLUE);
        add(manaBar);

        // Label for mana
        var manaText = new FlxText(manaBar.x + BAR_WIDTH + 5, manaBar.y, 100, "MP");
        manaText.setFormat(null, 12, FlxColor.WHITE);
        add(manaText);

        // Stamina bar
        staminaBar = new FlxBar(10, manaBar.y + manaBar.height + BAR_PADDING, LEFT_TO_RIGHT, BAR_WIDTH, BAR_HEIGHT, this, "stamina", 0, maxStamina);
        staminaBar.createFilledBar(FlxColor.GRAY, FlxColor.GREEN);
        add(staminaBar);

        // Label for stamina
        var staminaText = new FlxText(staminaBar.x + BAR_WIDTH + 5, staminaBar.y, 100, "SP");
        staminaText.setFormat(null, 12, FlxColor.WHITE);
        add(staminaText);

        // Experience bar
        expBar = new FlxBar(10, staminaBar.y + staminaBar.height + BAR_PADDING * 2, LEFT_TO_RIGHT, BAR_WIDTH, 8, this, "experience", 0, experienceNeeded);
        expBar.createFilledBar(FlxColor.GRAY, FlxColor.YELLOW);
        add(expBar);

        // Level text
        levelText = new FlxText(10, expBar.y + expBar.height + BAR_PADDING, 200);
        levelText.setFormat(null, 12, FlxColor.WHITE);
        add(levelText);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        // If player is dead, stop updating
        if (isDead) {
            return;
        }

        // Update level text
        levelText.text = "Level: " + level + " (" + Std.int(experience) + "/" + Std.int(experienceNeeded) + " XP)";
        if (skillPoints > 0) {
            levelText.text += " - Skill Points: " + skillPoints;
        }

        // Update bar ranges in case max values changed
        healthBar.setRange(0, maxHealth);
        manaBar.setRange(0, maxMana);
        staminaBar.setRange(0, maxStamina);
        expBar.setRange(0, experienceNeeded);

        // Resource regeneration
        if (!FlxG.keys.pressed.SHIFT && !sprite.isJumping && !isBlocking) {
            stamina += 30 * elapsed; // Faster stamina regen
        }
        mana += sprite.manaRegenRate * elapsed;
        health += sprite.healthRegenRate * elapsed;

        // Update combo timer
        if (attackComboTimer > 0) {
            attackComboTimer -= elapsed;
            if (attackComboTimer <= 0) {
                attackComboCount = 0; // Reset combo if timer runs out
            }
        }

        // Block handling
        if (FlxG.keys.pressed.Q && stamina > 0) {
            isBlocking = true;
            stamina -= BLOCK_DRAIN * elapsed;

            // Check for parry timing (when block is first pressed)
            if (FlxG.keys.justPressed.Q) {
                isParrying = true;
                parryTimer = PARRY_WINDOW;
            }
        } else {
            isBlocking = false;
        }

        // Update parry window
        if (isParrying) {
            parryTimer -= elapsed;
            if (parryTimer <= 0) {
                isParrying = false;
            }
        }

        // Attack input handling
        if (FlxG.mouse.justPressed && sprite.attackCooldownTimer <= 0 && stamina >= ATTACK_COST) {
            performAttack();
        }

        // Position attack hitbox in front of player based on facing
        updateAttackHitbox();

        // Clamp resources to maximum values
        stamina = FlxMath.bound(stamina, 0, maxStamina);
        mana = FlxMath.bound(mana, 0, maxMana);
        health = FlxMath.bound(health, 0, maxHealth);
    }

    private function updateAttackHitbox():Void {
        // Position hitbox in front of player based on angle
        var angle = sprite.angle * (Math.PI / 180); // Convert to radians
        // ATTACK_RANGE is now the base distance. The hitbox's current width/height determine its overall size.
        var currentRange = ATTACK_RANGE;

        var offsetX = Math.cos(angle) * currentRange;
        var offsetY = Math.sin(angle) * currentRange;

        attackHitbox.setPosition(
            sprite.x + sprite.width/2 - attackHitbox.width/2 + offsetX,
            sprite.y + sprite.height/2 - attackHitbox.height/2 + offsetY
        );
    }

    /**
     * Replaces the old performAttack method with combo logic and visual effects.
     */
    private function performAttack():Void {
        // Reset combo if too much time has passed since last attack
        if (FlxG.game.ticks - lastAttackTime > COMBO_WINDOW * 1000) {
            attackComboCount = 0;
        }

        // Increment combo counter (up to 3-hit combo)
        attackComboCount = (attackComboCount % 3) + 1; // Cycles 1, 2, 3

        // Set cooldown based on combo (faster follow-ups)
        var cooldownMultiplier = switch(attackComboCount) {
            case 1: 1.0;     // First hit: normal speed
            case 2: 0.85;    // Second hit: 15% faster
            case 3: 0.7;     // Third hit: 30% faster
            default: 1.0;    // Should not happen, but for safety
        };

        // Apply stamina cost
        sprite.attackCooldownTimer = ATTACK_COOLDOWN * cooldownMultiplier;
        stamina -= ATTACK_COST;
        lastAttackTime = FlxG.game.ticks;
        attackComboTimer = COMBO_WINDOW;

        // Show and enable attack hitbox
        attackHitbox.exists = true;
        attackHitbox.alpha = 0.4; // Semi-transparent for debugging

        // *** NEW APPROACH: SET WIDTH AND HEIGHT DIRECTLY ***
        var attackSizeMultiplier = attackComboCount == 3 ? 1.5 : 1.0;
        attackHitbox.width = BASE_HITBOX_WIDTH * attackSizeMultiplier;
        attackHitbox.height = BASE_HITBOX_HEIGHT * attackSizeMultiplier;
        // *** END NEW APPROACH ***

        // Visual attack effect (slash animation)
        createAttackEffect(attackComboCount);

        // Hide hitbox after a short duration
        new FlxTimer().start(0.2, function(_) {
            attackHitbox.exists = false;
            // Optionally, reset hitbox size after it disappears to be ready for next attack
            attackHitbox.width = BASE_HITBOX_WIDTH;
            attackHitbox.height = BASE_HITBOX_HEIGHT;
        });

        // Here we would check for collisions with enemies
        // This is handled in PlayState.hx
    }

    /**
     * Creates a visual attack effect at the player's attack point.
     * FIXED: Proper handling of scale tweening and distinct combo effects.
     */
    private function createAttackEffect(comboCount:Int):Void {
        // If we don't have an effect sprite yet, create one
        if (attackEffectSprite == null) {
            attackEffectSprite = new FlxSprite(0, 0);
            attackEffectSprite.makeGraphic(40, 40, FlxColor.WHITE); // Base size
            attackEffectSprite.alpha = 0;
            attackEffectSprite.centerOffsets();
            // Add to the state, not the player group, so it renders correctly even if player moves
            (cast FlxG.state).add(attackEffectSprite);
        }

        // Position the effect based on player facing
        var angle = sprite.angle * (Math.PI / 180); // Convert to radians
        var offsetX = Math.cos(angle) * (ATTACK_RANGE * 0.7); // Slightly closer to player
        var offsetY = Math.sin(angle) * (ATTACK_RANGE * 0.7);

        attackEffectSprite.setPosition(
            sprite.x + sprite.width/2 + offsetX - attackEffectSprite.width/2,
            sprite.y + sprite.height/2 + offsetY - attackEffectSprite.height/2
        );

        // Set color based on combo count
        var effectColor = switch(comboCount) {
            case 1: FlxColor.WHITE;
            case 2: FlxColor.fromRGB(200, 200, 255); // Light blue
            case 3: FlxColor.fromRGB(255, 200, 200); // Light red
            default: FlxColor.WHITE;
        };
        attackEffectSprite.color = effectColor;
        attackEffectSprite.angle = sprite.angle; // Match player's angle
        attackEffectSprite.alpha = 0.7; // Start semi-transparent

        // Scale based on combo (bigger for 3rd hit)
        var scaleMultiplier = comboCount == 3 ? 1.5 : 1.0;
        attackEffectSprite.scale.set(scaleMultiplier, scaleMultiplier);

        // FIXED: Tweening scale properties individually instead of as an object
        FlxTween.tween(attackEffectSprite, {alpha: 0}, 0.2);
        FlxTween.tween(attackEffectSprite.scale, {x: scaleMultiplier * 0.5, y: scaleMultiplier * 0.5}, 0.2);
    }

    /**
     * Modified takeDamage method with enhanced visual feedback for blocking and parrying.
     * FIXED: Proper handling of scale tweening
     */
    public function takeDamage(amount:Float):Void {
        if (isDead) return; // Don't take damage if already dead

        // Check for block/parry
        if (isBlocking) {
            if (isParrying) {
                // Perfect parry! No damage and maybe counterattack opportunity
                // Create a parry effect
                var parryEffect = new FlxSprite(sprite.x, sprite.y);
                parryEffect.makeGraphic(40, 40, FlxColor.CYAN);
                parryEffect.alpha = 0.7;
                parryEffect.centerOffsets();
                (cast FlxG.state).add(parryEffect); // Add to state

                // FIXED: Tweening scale properties individually
                FlxTween.tween(parryEffect, {alpha: 0}, 0.3, {
                    onComplete: function(_) {
                        (cast FlxG.state).remove(parryEffect);
                        parryEffect.destroy();
                    }
                });
                FlxTween.tween(parryEffect.scale, {x: 2.0, y: 2.0}, 0.3);

                // Give the player a brief window of opportunity
                sprite.attackCooldownTimer = 0; // Reset attack cooldown for immediate counter

                return; // No damage taken
            }

            // Regular block, reduced damage
            amount *= 0.3; // 70% damage reduction

            // Visual effect for blocking
            var blockEffect = new FlxSprite(sprite.x, sprite.y);
            blockEffect.makeGraphic(30, 30, FlxColor.BLUE);
            blockEffect.alpha = 0.5;
            blockEffect.centerOffsets();
            (cast FlxG.state).add(blockEffect); // Add to state

            // Animate the block effect
            FlxTween.tween(blockEffect, {alpha: 0}, 0.2, {
                onComplete: function(_) {
                    (cast FlxG.state).remove(blockEffect);
                    blockEffect.destroy();
                }
            });
        }

        // Only take damage if not in iframes
        if (sprite.iframeTimer <= 0) {
            health -= amount;
            sprite.iframeTimer = 0.5; // 500ms invulnerability after taking damage
            FlxFlicker.flicker(sprite, 0.5, 0.06, true, true, null, null);

            // Play hurt sound (commented out)
            // hurtSound.play();

            // Camera shake on hit, scaled by damage amount
            FlxG.camera.shake(0.005 * (amount / 10), 0.2); // Adjust multiplier as needed

            if (health <= 0) {
                die(); // Player dies if health drops to 0 or below
            }
        }
    }

    /**
     * Handles player death.
     */
    private function die():Void {
        isDead = true;
        health = 0; // Ensure health is 0
        sprite.visible = false; // Hide player sprite
        sprite.active = false; // Stop player sprite updates
        // Optionally, add a death animation or screen fade here
        FlxG.log.add("Player has died!");
        // In a real game, you'd likely transition to a game over screen
        // For now, just log and stop player input/updates.
        // You might want to remove the player from the state or reset the game.
    }

    // Make method public so it can be called from PlayState
    public function gainExperience(amount:Float):Void {
        experience += amount;
        while (experience >= experienceNeeded) {
            levelUp();
        }
    }

    private function levelUp():Void {
        level++;
        experience -= experienceNeeded;
        experienceNeeded = Math.floor(experienceNeeded * 1.5); // Increase XP needed for next level

        // Grant skill points
        skillPoints++;

        // Improve stats slightly with each level
        maxHealth += 5;
        maxMana += 3;
        maxStamina += 2;

        // Full heal on level up
        health = maxHealth;
        mana = maxMana;
        stamina = maxStamina;

        // Play level up sound (commented out)
        // levelUpSound.play();

        // Visual effect for level up
        FlxFlicker.flicker(sprite, 1, 0.1, true);
    }

    // Call this when player allocates stat points
    public function increaseStat(statType:String, amount:Int = 1):Void {
        if (skillPoints >= amount) {
            switch (statType.toLowerCase()) {
                case "intelligence", "int":
                    intelligence += amount;
                case "strength", "str":
                    strength += amount;
                case "health", "hp":
                    healthStat += amount;
                case "agility", "agi":
                    agility += amount;
                case "perception", "per":
                    perception += amount;
                default:
                    return; // Invalid stat, don't consume points
            }

            skillPoints -= amount;
            recalculateStats();
        }
    }

    private function recalculateStats():Void {
        // Update derived stats based on base stats
        maxHealth = 100 + (healthStat - 10) * 10;
        maxMana = 50 + (intelligence - 10) * 5;
        maxStamina = 100 + (agility - 10) * 3;

        sprite.healthRegenRate = 1 + (healthStat - 10) * 0.1;
        sprite.manaRegenRate = 5 + (intelligence - 10) * 0.5;

        critChance = 5 + (agility - 10) * 0.5;
        attackPower = 10 + (strength - 10) * 1.2;
        magicPower = 5 + (intelligence - 10) * 1.5;
        physicalDefense = 5 + (strength - 10) * 0.5;
        magicDefense = 5 + (intelligence - 10) * 0.5;

        // Perception effects would be handled separately in vision/detection code
    }

    // Call this to check if an attack is a critical hit
    public function rollForCritical():Bool {
        return FlxG.random.float(0, 100) <= critChance;
    }

    // Calculate final damage based on stats and combo multiplier
    public function calculateDamage(isPhysical:Bool = true, baseDamage:Float = -1):Float {
        var damage:Float;

        if (baseDamage < 0) {
            // Use player's own attack power if no base damage provided
            damage = isPhysical ? attackPower : magicPower;
        } else {
            damage = baseDamage;
        }

        // Apply combo damage multiplier
        var comboDamageMultiplier = switch(attackComboCount) {
            case 1: 1.0;
            case 2: 1.1;
            case 3: 1.25;
            default: 1.0;
        };
        damage *= comboDamageMultiplier;

        // Critical hit check is now handled in PlayState.playerAttackHitSprite
        // and passed to enemy.takeDamage for damage number display.
        // It's removed from here to prevent double-application or confusion.
        // The rollForCritical() method is still used by PlayState to determine if a hit is critical.

        return damage;
    }
}