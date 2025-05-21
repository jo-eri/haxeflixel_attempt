package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.math.FlxMath; // Added for FlxMath.roundDecimal in updateDebugText if not already there

class PlayState extends FlxState {
    var player:Player;

    var enemyGroup = new FlxTypedGroup<Enemy>(1);
    var obstacle:FlxSprite;
    var debugText:FlxText;
    var comboWindowText:FlxText; 

    private var spriteToEnemyMap:Map<FlxSprite, Enemy>;

    override public function create():Void {
        super.create();
        FlxG.cameras.bgColor = FlxColor.fromRGB(30, 30, 30);

        player = new Player(FlxG.width / 2, FlxG.height / 2);
        add(player);

        obstacle = new FlxSprite(FlxG.width / 2 + 100, FlxG.height / 2);
        obstacle.makeGraphic(32, 32, FlxColor.RED);
        obstacle.immovable = true;
        add(obstacle);

        enemyGroup = new FlxTypedGroup<Enemy>();
        add(enemyGroup);

        spawnEnemy(100, 100, Enemy.RANK_E);
        spawnEnemy(400, 300, Enemy.RANK_D);
        spawnEnemy(200, 400, Enemy.RANK_E);

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

        debugText = new FlxText(10, FlxG.height - 60, FlxG.width - 20);
        debugText.setFormat(null, 10, FlxColor.WHITE);
        add(debugText);

        comboWindowText = new FlxText(FlxG.width / 2, 30, 0, "COMBO!", 12);
        comboWindowText.setFormat(null, 12, FlxColor.YELLOW, "center");
        comboWindowText.visible = false;
        add(comboWindowText);

        spriteToEnemyMap = new Map<FlxSprite, Enemy>();
    }

    private function spawnEnemy(x:Float, y:Float, rank:Int):Void {
        var enemy = new Enemy(x, y, rank, player);
        enemyGroup.add(enemy);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        FlxG.collide(player.sprite, obstacle);
        FlxG.collide(getEnemySpritesGroup(), obstacle);
        FlxG.collide(player.sprite, getEnemySpritesGroup());

        if (player.attackHitbox.exists) {
            FlxG.overlap(player.attackHitbox, getEnemySpritesGroup(), playerAttackHitSprite);
        }

        updateDebugText();

        if (player != null && player.attackComboTimer > 0 && player.attackComboCount > 0) {
            comboWindowText.visible = true;
            comboWindowText.text = "COMBO: " + player.attackComboCount + " (" + FlxMath.roundDecimal(player.attackComboTimer, 2) + "s)";
        } else {
            comboWindowText.visible = false;
        }

        if (FlxG.keys.justPressed.E) player.gainExperience(25);
        if (FlxG.keys.justPressed.F) player.takeDamage(10);
    }

    private function getEnemySpritesGroup():FlxTypedGroup<FlxSprite> {
        var enemySpriteGroup = new FlxTypedGroup<FlxSprite>();
        spriteToEnemyMap.clear();
        for (enemy in enemyGroup) {
            if (enemy != null && enemy.exists && !enemy.isDead) {
                spriteToEnemyMap.set(enemy.sprite, enemy);
                enemySpriteGroup.add(enemy.sprite);
            }
        }
        return enemySpriteGroup;
    }

    private function playerAttackHitSprite(attackHitbox:FlxSprite, enemySprite:FlxSprite):Void {
        if (attackHitbox.exists && enemySprite.exists) {
            var enemy:Enemy = spriteToEnemyMap.get(enemySprite);
            if (enemy != null && enemy.exists && !enemy.isDead) {
                var damage = player.calculateDamage(true);
                var isCritical = player.rollForCritical();
                enemy.takeDamage(damage, 150, isCritical);
                createHitEffect(enemySprite.x + enemySprite.width/2, enemySprite.y + enemySprite.height/2, isCritical);
                // Screen shake for general impactful hits (already existed)
                if (damage > 20 || isCritical) { // Kept existing logic, crits will also trigger this
                    FlxG.camera.shake(0.005, 0.1);
                }
            }
        }
    }

    /**
     * Creates a small visual effect at the hit location.
     * Enhanced critical hit effect.
     */
	private function createHitEffect(x:Float, y:Float, isCritical:Bool = false):Void {
			var hitEffect = new FlxSprite(x, y);
			var baseWidth = 20;
			var baseHeight = 20;

			if (isCritical) {
				// Enhanced critical hit effect
				hitEffect.makeGraphic(Std.int(baseWidth * 2.0), Std.int(baseHeight * 2.0), FlxColor.ORANGE); // Larger and Orange
                if (FlxG.camera != null) { // Ensure camera exists
				    FlxG.camera.shake(0.004, 0.07); // Specific small shake for critical visual
                }
			} else {
				// Normal hit effect
				hitEffect.makeGraphic(baseWidth, baseHeight, FlxColor.WHITE);
			}

			hitEffect.x -= hitEffect.width / 2;
			hitEffect.y -= hitEffect.height / 2;
			hitEffect.alpha = 1; 
			add(hitEffect); 

			FlxTween.tween(hitEffect, {alpha: 0, width: 0, height: 0}, 0.3, {
				onComplete: function(_) {
					remove(hitEffect);
					hitEffect.destroy();
				}
			});
		}

    private function updateDebugText():Void {
        var jumpCooldownFormatted = Math.round(player.sprite.jumpCooldownTimer * 100) / 100;
        var iframeFormatted = Math.round(player.sprite.iframeTimer * 100) / 100;
        var attackCooldownFormatted = Math.round(player.sprite.attackCooldownTimer * 100) / 100;
        var comboTimerFormatted = Math.round(player.attackComboTimer * 100) / 100;

        // Using FlxMath.roundDecimal for potentially cleaner output if available
        // If FlxMath.roundDecimal is not available or causes issues, revert to Math.round(val * 100) / 100
        debugText.text =
            "Velocity: (" + FlxMath.roundDecimal(player.sprite.velocity.x, 2) + ", " + FlxMath.roundDecimal(player.sprite.velocity.y, 2) + ") " +
            "Speed: " + FlxMath.roundDecimal(player.sprite.velocity.length, 2) + "\n" +
            "Position: (" + FlxMath.roundDecimal(player.sprite.x, 2) + ", " + FlxMath.roundDecimal(player.sprite.y, 2) + ") " +
            "Jumping: " + player.sprite.isJumping + " " +
            "Jump Cooldown: " + FlxMath.roundDecimal(player.sprite.jumpCooldownTimer, 2) + " " +
            "IFrames: " + FlxMath.roundDecimal(player.sprite.iframeTimer, 2) + "\n" +
            "Attack Cooldown: " + FlxMath.roundDecimal(player.sprite.attackCooldownTimer, 2) + " " +
            "Attack Combo: " + player.attackComboCount + " " +
            "Combo Timer: " + FlxMath.roundDecimal(player.attackComboTimer, 2);
    }
}
