import SpriteKit

final class SpawnSystem {
    private let pool: EnemyPool
    private weak var cameraNode: SKCameraNode?

    private var spawnAccumulator: CGFloat = 0

    init(pool: EnemyPool, cameraNode: SKCameraNode) {
        self.pool = pool
        self.cameraNode = cameraNode
    }

    func update(elapsed: TimeInterval, dt: TimeInterval, playerPos: CGPoint, isSpawningEnabled: Bool) -> [EnemyNode] {
        guard isSpawningEnabled else { return [] }

        // Continuous difficulty curve: smooth ramp from ~2/sec to ~16/sec over first 4:45.
        // No discrete waves — a single formula driven by elapsed time.
        let t = CGFloat(min(elapsed, 285)) // stop ramping after 4:45
        let x = (t / 285).clamped(0, 1)
        let eased = x * x * (3 - 2 * x) // smoothstep
        let enemiesPerSec: CGFloat = 2 + 14 * eased
        spawnAccumulator += enemiesPerSec * CGFloat(dt)

        var spawned: [EnemyNode] = []
        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            // Brutes blend in after 1:00 and become more common over time.
            let bruteBlend = ((CGFloat(elapsed) - 60) / 150).clamped(0, 1) // 0 at 1:00, ~1 by 3:30
            let bruteChance: Double = 0.12 + Double(bruteBlend) * 0.22
            let spawnBrute = elapsed >= 60 && Double.random(in: 0...1) < bruteChance
            let enemy = spawnBrute ? pool.acquireBrute() : pool.acquireScuttler()
            guard let enemy else { break }
            enemy.position = randomSpawnPositionNearCameraEdge(playerPos: playerPos)
            spawned.append(enemy)
        }
        return spawned
    }

    private func randomSpawnPositionNearCameraEdge(playerPos: CGPoint) -> CGPoint {
        guard let cam = cameraNode else { return playerPos }
        let w = cam.scene?.size.width ?? 0
        let h = cam.scene?.size.height ?? 0
        let halfW = w * 0.5
        let halfH = h * 0.5
        let margin: CGFloat = 40

        let side = Int.random(in: 0..<4)
        switch side {
        case 0: // left
            return CGPoint(x: playerPos.x - halfW - margin, y: playerPos.y + CGFloat.random(in: -halfH...halfH))
        case 1: // right
            return CGPoint(x: playerPos.x + halfW + margin, y: playerPos.y + CGFloat.random(in: -halfH...halfH))
        case 2: // bottom
            return CGPoint(x: playerPos.x + CGFloat.random(in: -halfW...halfW), y: playerPos.y - halfH - margin)
        default: // top
            return CGPoint(x: playerPos.x + CGFloat.random(in: -halfW...halfW), y: playerPos.y + halfH + margin)
        }
    }
}

