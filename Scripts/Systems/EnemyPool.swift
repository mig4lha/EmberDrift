import SpriteKit

final class EnemyPool {
    private var pool: [EnemyNode] = []
    private let capacity: Int
    private let parent: SKNode
    private var createdCount: Int = 0

    init(parent: SKNode, capacity: Int) {
        self.parent = parent
        self.capacity = capacity
        pool.reserveCapacity(capacity)
    }

    func acquireScuttler() -> EnemyNode? {
        acquire(kind: .scuttler, radius: 14, maxHP: GameConstants.scuttlerMaxHP, speed: GameConstants.scuttlerBaseSpeed, contactDamage: GameConstants.scuttlerContactDamage)
    }

    func acquireBrute() -> EnemyNode? {
        acquire(kind: .brute, radius: 20, maxHP: GameConstants.bruteMaxHP, speed: GameConstants.bruteBaseSpeed, contactDamage: GameConstants.bruteContactDamage)
    }

    func release(_ enemy: EnemyNode) {
        enemy.removeAllActions()
        enemy.isHidden = true
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.none
        enemy.position = CGPoint(x: 999_999, y: 999_999)
        pool.append(enemy)
    }

    private func acquire(kind: EnemyKind, radius: CGFloat, maxHP: CGFloat, speed: CGFloat, contactDamage: CGFloat) -> EnemyNode? {
        if let existing = pool.popLast() {
            existing.reset(maxHP: maxHP, moveSpeed: speed, contactDamage: contactDamage)
            existing.physicsBody?.categoryBitMask = PhysicsCategory.enemy
            existing.physicsBody?.contactTestBitMask = PhysicsCategory.player
            existing.isHidden = false
            return existing
        }

        guard createdCount < capacity else { return nil }
        let enemy = EnemyNode(kind: kind, maxHP: maxHP, moveSpeed: speed, contactDamage: contactDamage, radius: radius)
        createdCount += 1
        parent.addChild(enemy)
        return enemy
    }
}

