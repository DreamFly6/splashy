//
//  GameScene.swift
//  splashy
//
//  Created by David Thompson on 19/11/2018.
//  Copyright © 2018 the beardy developer. All rights reserved.
//


import SpriteKit
import GameplayKit


struct PhysicsCategory {
    static let Player: UInt32 = 0x1 << 1
    static let Wall: UInt32 = 0x1 << 2
    static let Score: UInt32 = 0x1 << 3
}


class GameScene: SKScene, SKPhysicsContactDelegate {
    // Defaults
    var score: Int = 0
    var died: Bool = false
    var gameStarted: Bool = false
    var enableUnderwaterPhysics: Bool = true

    // Sprites / Nodes
    var player: Player!
    var water: SBDynamicWaterNode!
    var wallPair: SKNode!
    var scoreNode: SKSpriteNode!
    var restartButton: SKSpriteNode!

    // Labels
    var scoreLabel: SKLabelNode!

    // Actions
    var spawnDelayForever: SKAction!
    var moveAndRemove: SKAction!

    // Water Animation
    var hasReferenceFrameTime: Bool = false
    var lastFrameTime: CFTimeInterval!
    let kFixedTimeStep = 1.0 / 500
    var kSurfaceHeight: CGFloat!

    // Water Physics
    let VISCOSITY: CGFloat = 4 // Increase to make the water "thicker/stickier," creating more friction.
    let BUOYANCY: CGFloat = 0.4 // Slightly increase to make the object "float up faster," more buoyant.
    var OFFSET: CGFloat!

    func restartScene() {
        self.removeAllChildren()
        self.removeAllActions()
        died = false
        gameStarted = false
        score = 0
        createScene()
    }

    func createScene() {
        kSurfaceHeight = self.size.height / 2.5
        OFFSET = kSurfaceHeight / 3.5 // Decrease to make the object float to the surface higher.

        self.physicsWorld.contactDelegate = self


        // Score Label
        scoreLabel = SKLabelNode()
        scoreLabel.fontSize = 50
        scoreLabel.position = CGPoint(x: self.frame.width / 2, y: (self.frame.height / 2) + (self.frame.height / 2.5))
        scoreLabel.zPosition = 5
        scoreLabel.text = "\(score)"
        self.addChild(scoreLabel)

        // Player
        player = Player()
        player.position = CGPoint(x:300, y:kSurfaceHeight + 50)
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.categoryBitMask = PhysicsCategory.Player
        player.physicsBody?.collisionBitMask = PhysicsCategory.Wall
        player.physicsBody?.contactTestBitMask = PhysicsCategory.Wall | PhysicsCategory.Score
        self.addChild(player)

        // Water
        water = SBDynamicWaterNode(width: Float(self.size.width), numJoints:150, surfaceHeight:Float(kSurfaceHeight), fillColour: UIColor(red:0, green:0, blue:1, alpha:0.5))
        water.position = CGPoint(x:self.size.width/2, y:0)
        self.addChild(water)
        water.setDefaultValues()

        // Walls
        let spawn = SKAction.run {
            () in
            self.createWalls()
        }

        let delay = SKAction.wait(forDuration: 2.0)
        let spawnDelay = SKAction.sequence([spawn, delay])
        spawnDelayForever = SKAction.repeatForever(spawnDelay)

        let distance = CGFloat(self.frame.width)
        let movePipes = SKAction.moveBy(x: -distance, y: 0, duration: TimeInterval(0.0025 * distance))
        let removePipes = SKAction.removeFromParent()
        moveAndRemove = SKAction.sequence([movePipes, removePipes])

        // Scene
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
    }

    override func didMove(to view: SKView) {
        createScene()
    }

    override func update(_ currentTime: CFTimeInterval) {
        if (!self.hasReferenceFrameTime) {
            self.lastFrameTime = currentTime
            self.hasReferenceFrameTime = true
            return
        }

        let dt: CFTimeInterval = currentTime - self.lastFrameTime!

        var accumilator: CFTimeInterval = 0
        accumilator += dt

        while (accumilator >= kFixedTimeStep) {
            self.fixedUpdate(kFixedTimeStep)
            accumilator -= kFixedTimeStep
        }
        self.fixedUpdate(accumilator)

        // Player is underwater
        if !player.isAboveWater && enableUnderwaterPhysics {
            player.applyUnderwaterPhysics(waterY: water.position.y, surfaceHeight: kSurfaceHeight)
        }

        self.lateUpdate(dt)
        self.lastFrameTime = currentTime
    }

    func fixedUpdate(_ currentTime: CFTimeInterval) {
        water.update(currentTime)

        let y = player.position.y
        let x = player.position.x
        let yVel = player.physicsBody?.velocity.dy

        // Player is going underwater
        if player.isAboveWater && Float(y) <= water.surfaceHeight {
            player.isAboveWater = false
            water.splashAt(x:Float(x), force:-yVel! * 0.075, width:20)
        }
        // Player is going above water
        if !player.isAboveWater && Float(y) > water.surfaceHeight {
            player.isAboveWater = true
            // lower multiplier due to velocity put on when jumping from water
            water.splashAt(x:Float(x), force:-yVel! * 0.05, width:20)
        }
    }

    func lateUpdate(_ currentTime: CFTimeInterval) {
        water.render()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !gameStarted {
            self.run(spawnDelayForever)
            gameStarted = true
        }
        // you ded
        if died {
            return
        }
        enableUnderwaterPhysics = false
        if !player.isAboveWater {
            player.physicsBody?.velocity = CGVector(dx: 0, dy: (player.physicsBody?.velocity.dy)! / 2)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        enableUnderwaterPhysics = true
        if !died && !player.isAboveWater {
            let playerY = player.position.y
            player.physicsBody?.velocity = CGVector(dx: 0, dy: 6.25 * (kSurfaceHeight - playerY))
        }

        for touch in touches {
            let location = touch.location(in: self)

            if died {
                if restartButton.contains(location) {
                    restartScene()
                }
            }
        }
    }

    func createWalls() {
        scoreNode = SKSpriteNode()
        wallPair = SKNode()

        let gapSize = CGFloat(350)
        let wallScale = CGFloat(0.5)

        let topWall = SKSpriteNode(texture: nil, color: UIColor.green, size: CGSize(width: 40, height: 1000))
        let bottomWall = SKSpriteNode(texture: nil, color: UIColor.green, size: CGSize(width: 40, height: 1000))

        scoreNode.size = CGSize(width: 1, height: (gapSize * 2) - (topWall.size.height * wallScale))
        scoreNode.position = CGPoint(x: self.frame.width, y: self.frame.height / 2)
        scoreNode.physicsBody = SKPhysicsBody(rectangleOf: scoreNode.size)
        scoreNode.physicsBody?.categoryBitMask = PhysicsCategory.Score
        scoreNode.physicsBody?.collisionBitMask = 0
        scoreNode.physicsBody?.contactTestBitMask = PhysicsCategory.Player
        scoreNode.physicsBody?.affectedByGravity = false
        scoreNode.physicsBody?.isDynamic = false

        topWall.position = CGPoint(x: self.frame.width, y: self.frame.height / 2 + gapSize)
        bottomWall.position = CGPoint(x: self.frame.width, y: self.frame.height / 2 - gapSize)

        topWall.setScale(wallScale)
        bottomWall.setScale(wallScale)

        topWall.physicsBody = SKPhysicsBody(rectangleOf: topWall.size)
        topWall.physicsBody?.categoryBitMask = PhysicsCategory.Wall
        topWall.physicsBody?.collisionBitMask = PhysicsCategory.Player
        topWall.physicsBody?.contactTestBitMask = PhysicsCategory.Player
        topWall.physicsBody?.affectedByGravity = false
        topWall.physicsBody?.isDynamic = false

        bottomWall.physicsBody = SKPhysicsBody(rectangleOf: topWall.size)
        bottomWall.physicsBody?.categoryBitMask = PhysicsCategory.Wall
        bottomWall.physicsBody?.collisionBitMask = PhysicsCategory.Player
        bottomWall.physicsBody?.contactTestBitMask = PhysicsCategory.Player
        bottomWall.physicsBody?.affectedByGravity = false
        bottomWall.physicsBody?.isDynamic = false

        wallPair.addChild(topWall)
        wallPair.addChild(bottomWall)

        let randomPosition = CGFloat.random(min: -200, max: 200)
        wallPair.position.y = wallPair.position.y + randomPosition

        wallPair.addChild(scoreNode)

        wallPair.run(moveAndRemove)

        self.addChild(wallPair)
    }

    func createRestartButton() {
        restartButton = SKSpriteNode(color: UIColor.white, size: CGSize(width: 300, height: 200))
        restartButton.position = CGPoint(x: self.frame.width / 2, y: self.frame.height / 2)
        restartButton.zPosition = 6
        self.addChild(restartButton)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody = contact.bodyA
        let secondBody = contact.bodyB

        if !died && (firstBody.categoryBitMask == PhysicsCategory.Score && secondBody.categoryBitMask == PhysicsCategory.Player || firstBody.categoryBitMask == PhysicsCategory.Player && secondBody.categoryBitMask == PhysicsCategory.Score) {
            score += 1
            scoreLabel.text = "\(score)"
        }

        if firstBody.categoryBitMask == PhysicsCategory.Player && secondBody.categoryBitMask == PhysicsCategory.Wall || firstBody.categoryBitMask == PhysicsCategory.Wall && secondBody.categoryBitMask == PhysicsCategory.Player {
            died = true
            createRestartButton()
        }
    }
}
