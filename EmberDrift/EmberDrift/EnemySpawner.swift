import SpriteKit

final class EnemySpawner {
    struct EnemyTuning {
        let scuttlerRadius: CGFloat
        let scuttlerSpeed: CGFloat
        let scuttlerHP: CGFloat
        let scuttlerContactDamage: CGFloat

        let bruteRadius: CGFloat
        let bruteSpeed: CGFloat
        let bruteHP: CGFloat
        let bruteContactDamage: CGFloat
    }

    private let world: SKNode
    private let tuning: EnemyTuning
    private var spawnAccumulator: CGFloat = 0

    init(world: SKNode, tuning: EnemyTuning) {
        self.world = world
        self.tuning = tuning
    }

    func step(dt: CGFloat, elapsed: TimeInterval, bossExists: Bool, sceneSize: CGSize, playerPosition: CGPoint, enemies: inout [EnemyNode]) {
        guard dt > 0 else { return }
        // Stop spawns at 4:45 per GDD (void surge prep)
        guard elapsed < 285 else { return }
        guard !bossExists else { return }

        spawnAccumulator += spawnRate(elapsedSeconds: elapsed) * dt
        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            spawnOne(elapsed: elapsed, sceneSize: sceneSize, playerPosition: playerPosition, enemies: &enemies)
        }
    }

    private func spawnOne(elapsed: TimeInterval, sceneSize: CGSize, playerPosition: CGPoint, enemies: inout [EnemyNode]) {
        // Brutes are introduced at 1:00.
        let hasBrutes = elapsed >= 60
        let shouldSpawnBrute = hasBrutes && Double.random(in: 0...1) < 0.22
        if shouldSpawnBrute {
            spawnBrute(sceneSize: sceneSize, playerPosition: playerPosition, enemies: &enemies)
        } else {
            spawnScuttler(sceneSize: sceneSize, playerPosition: playerPosition, enemies: &enemies)
        }
    }

    private func spawnScuttler(sceneSize: CGSize, playerPosition: CGPoint, enemies: inout [EnemyNode]) {
        let enemy = EnemyNode(
            kind: .scuttler,
            radius: tuning.scuttlerRadius,
            maxHP: tuning.scuttlerHP,
            moveSpeed: tuning.scuttlerSpeed,
            contactDamage: tuning.scuttlerContactDamage
        )
        enemy.position = spawnPointOutsideCamera(sceneSize: sceneSize, playerPosition: playerPosition)
        world.addChild(enemy)
        enemies.append(enemy)
    }

    private func spawnBrute(sceneSize: CGSize, playerPosition: CGPoint, enemies: inout [EnemyNode]) {
        let enemy = EnemyNode(
            kind: .brute,
            radius: tuning.bruteRadius,
            maxHP: tuning.bruteHP,
            moveSpeed: tuning.bruteSpeed,
            contactDamage: tuning.bruteContactDamage
        )
        enemy.position = spawnPointOutsideCamera(sceneSize: sceneSize, playerPosition: playerPosition)
        world.addChild(enemy)
        enemies.append(enemy)
    }

    private func spawnRate(elapsedSeconds t: TimeInterval) -> CGFloat {
        // Continuous curve approximating the design table.
        // 0:00 2/s → 1:00 4/s → 2:00 7/s → 3:00 11/s → 4:00 16/s
        func lerp(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat { a + (b - a) * x }
        func segment(_ t0: TimeInterval, _ t1: TimeInterval, _ r0: CGFloat, _ r1: CGFloat, _ t: TimeInterval) -> CGFloat {
            let x = CGFloat((t - t0) / max(0.0001, (t1 - t0)))
            return lerp(r0, r1, max(0, min(1, x)))
        }

        if t < 60 { return segment(0, 60, 2, 4, t) }
        if t < 120 { return segment(60, 120, 4, 7, t) }
        if t < 180 { return segment(120, 180, 7, 11, t) }
        if t < 240 { return segment(180, 240, 11, 16, t) }
        return 16
    }

    private func spawnPointOutsideCamera(sceneSize: CGSize, playerPosition: CGPoint) -> CGPoint {
        // Spawn just outside visible area around the camera/player.
        let halfW = sceneSize.width * 0.5
        let halfH = sceneSize.height * 0.5
        let margin: CGFloat = 40

        let side = Int.random(in: 0..<4)
        switch side {
        case 0: // left
            return CGPoint(x: playerPosition.x - halfW - margin, y: playerPosition.y + CGFloat.random(in: -halfH...halfH))
        case 1: // right
            return CGPoint(x: playerPosition.x + halfW + margin, y: playerPosition.y + CGFloat.random(in: -halfH...halfH))
        case 2: // bottom
            return CGPoint(x: playerPosition.x + CGFloat.random(in: -halfW...halfW), y: playerPosition.y - halfH - margin)
        default: // top
            return CGPoint(x: playerPosition.x + CGFloat.random(in: -halfW...halfW), y: playerPosition.y + halfH + margin)
        }
    }
}

