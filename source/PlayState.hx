package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween; // Added for hit effect animation
import flixel.util.FlxColor;

class PlayState extends FlxState {
    var player:Player;

    // Enemy group
    var enemyGroup = new FlxTypedGroup<Enemy>(1);

    // Simple obstacle for testing
    var obstacle:FlxSprite;

    // Debug text
    var debugText:FlxText;

    private var spriteToEnemyMap:Map<FlxSprite, Enemy>;

    override public function create():Void {
        super.create();
        FlxG.cameras.bgColor = FlxColor.fromRGB(30, 30, 30);

        // Create player (which now includes its UI)
        player = new Player(FlxG.width / 2, FlxG.height / 2);
        add(player);

        // Create a test obstacle
        obstacle = new FlxSprite(FlxG.width / 2 + 100, FlxG.height / 2);
        obstacle.makeGraphic(32, 32, FlxColor.RED);
        obstacle.immovable = true;
        add(obstacle);

        // Create enemy group
        enemyGroup = new FlxTypedGroup<Enemy>();
        add(enemyGroup);

        // Spawn a few test enemies
        spawnEnemy(100, 100, Enemy.RANK_E);
        spawnEnemy(400, 300, Enemy.RANK_D);
        spawnEnemy(200, 400, Enemy.RANK_E);

        // Instructions
        var info = new FlxText(FlxG.width - 310, 10, 300,
            "WASD/Arrow keys to move\n" +
            "Shift to sprint (drains stamina)\n" +
            "Space to jump/dodge (costs stamina)\n" +
            "Mouse Click to attack\n" +
            "Q to block/parry\n" +
            "Aim with mouse\n\n" +
            "E - Gain experience\n" +
            "F - Take damage\n\n" +
            "Test your combat on the enemy!");
        info.setFormat(null, 12, FlxColor.YELLOW, "left");
        add(info);

        // Debug text to show player velocity and position
        debugText = new FlxText(10, FlxG.height - 60, FlxG.width - 20);
        debugText.setFormat(null, 10, FlxColor.WHITE);
        add(debugText);

        spriteToEnemyMap = new Map<FlxSprite, Enemy>();
    }

    /**
     * Spawn an enemy in the game world
     */
    private function spawnEnemy(x:Float, y:Float, rank:Int):Void {
        var enemy = new Enemy(x, y, rank, player);
        enemyGroup.add(enemy);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        // Collision between player sprite and obstacle
        FlxG.collide(player.sprite, obstacle);

        // Collision between enemies and obstacles
        FlxG.collide(getEnemySpritesGroup(), obstacle); // Use the new group method

        // Collision between player and enemies
        FlxG.collide(player.sprite, getEnemySpritesGroup()); // Use the new group method

        // Check for player attacks hitting enemies - fixed implementation
        if (player.attackHitbox.exists) {
            FlxG.overlap(player.attackHitbox, getEnemySpritesGroup(), playerAttackHitSprite);
        }

        // Update debug information
        updateDebugText();

        // Test experience gain with E key
        if (FlxG.keys.justPressed.E) {
            player.gainExperience(25);
        }

        // Test damage with F key
        if (FlxG.keys.justPressed.F) {
            player.takeDamage(10);
        }
    }

    /**
     * Helper to get all enemy sprites for collision as a FlxTypedGroup
     */
    private function getEnemySpritesGroup():FlxTypedGroup<FlxSprite> {
        var enemySpriteGroup = new FlxTypedGroup<FlxSprite>();

        // Clear and rebuild the map for accurate lookup
        spriteToEnemyMap.clear();

        for (enemy in enemyGroup) {
            if (enemy != null && enemy.exists && !enemy.isDead) {
                // Map the sprite to its parent enemy
                spriteToEnemyMap.set(enemy.sprite, enemy);
                enemySpriteGroup.add(enemy.sprite);
            }
        }
        return enemySpriteGroup;
    }

    /**
     * Handle player attack hitting an enemy sprite.
     * Looks up the corresponding Enemy object from spriteToEnemyMap.
     */
    private function playerAttackHitSprite(attackHitbox:FlxSprite, enemySprite:FlxSprite):Void {
        if (attackHitbox.exists && enemySprite.exists) {
            // Look up the parent enemy object from our map
            var enemy:Enemy = spriteToEnemyMap.get(enemySprite);

            if (enemy != null && enemy.exists && !enemy.isDead) {
                // Calculate damage based on player stats
                var damage = player.calculateDamage(true);
                var isCritical = player.rollForCritical();

                // Apply critical damage if applicable (damage multiplier is now handled in Player.calculateDamage)
                // If isCritical is true, the damage passed to enemy.takeDamage will already be doubled.

                // Apply damage with knockback
                enemy.takeDamage(damage, 150, isCritical); // Pass isCritical for damage number feedback

                // Show hit effect
                createHitEffect(enemySprite.x + enemySprite.width/2, enemySprite.y + enemySprite.height/2, isCritical);

                // Add screen shake for impactful hits
                if (damage > 20 || isCritical) {
                    FlxG.camera.shake(0.005, 0.1);
                }
            }
        }
    }

    /**
     * Creates a small visual effect at the hit location.
     */
	private function createHitEffect(x:Float, y:Float, isCritical:Bool = false):Void {
			var hitEffect = new FlxSprite(x, y);

			// Define base dimensions for the effect
			var baseWidth = 20;
			var baseHeight = 20;

			if (isCritical) {
				// Critical hit effect (yellow/orange)
				hitEffect.makeGraphic(Std.int(baseWidth * 1.5), Std.int(baseHeight * 1.5), FlxColor.YELLOW); // Set initial larger size
				// No hitEffect.scale.set() here!
			} else {
				// Normal hit effect (white)
				hitEffect.makeGraphic(baseWidth, baseHeight, FlxColor.WHITE); // Set initial normal size
			}

			// Center the effect on the given coordinates
			hitEffect.x -= hitEffect.width / 2;
			hitEffect.y -= hitEffect.height / 2;

			hitEffect.alpha = 1; // Start fully visible
			add(hitEffect); // Add to the state

			// Animate the effect to fade out and shrink
			FlxTween.tween(hitEffect, {alpha: 0, width: 0, height: 0}, 0.3, { // Tween width and height to 0
				onComplete: function(_) {
					remove(hitEffect);
					hitEffect.destroy();
				}
			});
		}

    private function updateDebugText():Void {
        // Format float to 2 decimal places
        var jumpCooldownFormatted = Math.round(player.sprite.jumpCooldownTimer * 100) / 100;
        var iframeFormatted = Math.round(player.sprite.iframeTimer * 100) / 100;
        var attackCooldownFormatted = Math.round(player.sprite.attackCooldownTimer * 100) / 100;
        var comboTimerFormatted = Math.round(player.attackComboTimer * 100) / 100;

        debugText.text =
            "Velocity: (" + Math.round(player.sprite.velocity.x) + ", " + Math.round(player.sprite.velocity.y) + ") " +
            "Speed: " + Math.round(player.sprite.velocity.length) + "\n" +
            "Position: (" + Math.round(player.sprite.x) + ", " + Math.round(player.sprite.y) + ") " +
            "Jumping: " + player.sprite.isJumping + " " +
            "Jump Cooldown: " + jumpCooldownFormatted + " " +
            "IFrames: " + iframeFormatted + "\n" +
            "Attack Cooldown: " + attackCooldownFormatted + " " +
            "Attack Combo: " + player.attackComboCount + " " +
            "Combo Timer: " + comboTimerFormatted;
    }
}
