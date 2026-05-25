import SwiftUI
import AppKit
import Combine

// MARK: - Data Types

enum BreakoutPhase: Equatable {
    case idle       // waiting for first hover
    case playing
    case paused
    case levelUp    // brief between levels
    case lifeLost   // lost a life, brief pause before continuing
    case gameOver
}

struct BrickCell {
    let col: Int
    let row: Int
    var alive: Bool = true
    var flashAge: CGFloat = 0   // >0 for a brief white-flash on hit
}

struct ScorePopup: Identifiable {
    let id = UUID()
    var text: String
    var pos: CGPoint
    var age: CGFloat = 0   // 0→1
}

// MARK: - Game Engine

@MainActor
final class BreakoutEngine: ObservableObject {

    // ── Canvas ──────────────────────────────────────────────────
    static let W: CGFloat = 660 // Padding to prevent clipping into notch radius
    static let H: CGFloat = 150

    // ── Bricks ──────────────────────────────────────────────────
    let brickCols  = 14
    let brickRows  = 5
    let brickGapX: CGFloat = 2
    let brickGapY: CGFloat = 2
    let brickH:    CGFloat = 11
    let sidePad:   CGFloat = 8
    let brickTopY: CGFloat = 0

    // ── Ball & Paddle ───────────────────────────────────────────
    let ballR:    CGFloat = 4.5
    let paddleW:  CGFloat = 80
    let paddleH:  CGFloat = 6
    let paddleBottomPad: CGFloat = 10

    // ── Published ───────────────────────────────────────────────
    @Published var phase:    BreakoutPhase = .idle
    @Published var bricks:   [BrickCell]   = []
    @Published var ballPos:  CGPoint       = .zero
    @Published var ballVel:  CGPoint       = .zero
    @Published var trail:    [CGPoint]     = []   // last 8 ball positions
    @Published var paddleX:  CGFloat       = W / 2
    @Published var score:    Int = 0
    @Published var hiScore:  Int = 0
    @Published var lives:    Int = 3
    @Published var level:    Int = 1
    @Published var popups:   [ScorePopup]  = []
    @Published var combo:    Int = 0
    @Published var screenFlash: CGFloat = 0  // 0-1 white flash on brick break
    var frameCount: Int = 0

    // ── Input State ─────────────────────────────────────────────
    var leftHeld:  Bool = false
    var rightHeld: Bool = false
    let paddleSpeed: CGFloat = 340   // points per second

    // ── Internal ────────────────────────────────────────────────
    private var speedMul: CGFloat = 1.0   // increases each level

    // ── Computed ────────────────────────────────────────────────
    var brickW: CGFloat {
        let usable = Self.W - 2 * sidePad
        return (usable - CGFloat(brickCols - 1) * brickGapX) / CGFloat(brickCols)
    }

    var paddleY: CGFloat { Self.H - paddleBottomPad - paddleH }

    let rowColors: [Color] = [
        Color(hue: 0.97, saturation: 0.85, brightness: 1.0),  // row 0 – red/pink
        Color(hue: 0.06, saturation: 0.88, brightness: 1.0),  // row 1 – orange
        Color(hue: 0.14, saturation: 0.85, brightness: 1.0),  // row 2 – yellow
        Color(hue: 0.36, saturation: 0.85, brightness: 1.0),  // row 3 – green
        Color(hue: 0.57, saturation: 0.85, brightness: 1.0),  // row 4 – cyan
    ]

    let rowPoints = [50, 30, 20, 10, 5]

    // ── Init ─────────────────────────────────────────────────────
    init() {
        hiScore = UserDefaults.standard.integer(forKey: "notchBreaker.hi")
        reset(keepHi: true)
    }

    // MARK: - Setup

    func reset(keepHi: Bool = false) {
        if !keepHi { hiScore = 0 }
        buildBricks()
        score  = 0
        lives  = 3
        level  = 1
        combo  = 0
        speedMul = 1.0
        popups = []
        trail  = []
        screenFlash = 0
        phase  = .idle
        paddleX = Self.W / 2
        placeBall()
    }

    func buildBricks() {
        bricks = []
        let currentLevel = min(level, 10)
        
        // Simple deterministic random for the level
        var seed = UInt64(currentLevel * 12345)
        func rand() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) * (1.0 / 9007199254740992.0)
        }
        
        for row in 0..<brickRows {
            for col in 0..<brickCols {
                let threshold = currentLevel == 1 ? 1.0 : (0.95 - Double(currentLevel) * 0.04)
                if rand() <= threshold {
                    bricks.append(BrickCell(col: col, row: row))
                }
            }
        }
        if bricks.isEmpty { bricks.append(BrickCell(col: brickCols/2, row: brickRows/2)) }
    }

    func brickRect(col: Int, row: Int) -> CGRect {
        let x = sidePad + CGFloat(col) * (brickW + brickGapX)
        let y = brickTopY + CGFloat(row) * (brickH + brickGapY)
        return CGRect(x: x, y: y, width: brickW, height: brickH)
    }

    func placeBall() {
        ballPos = CGPoint(x: paddleX, y: paddleY - ballR - 1)
        let speed: CGFloat = (1.6 + CGFloat(level - 1) * 0.125) * speedMul // Halved for 120fps
        let angleDeg = Double.random(in: 40...140)
        let rad = angleDeg * .pi / 180
        ballVel = CGPoint(
            x:  CGFloat(cos(rad)) * speed,
            y: -CGFloat(sin(rad)) * speed
        )
        trail = []
    }

    // MARK: - Update Loop
    
    /// The main 120fps physics step.
    func tick(dt: CGFloat) {
        guard phase == .playing else { return }
        frameCount += 1
        let half = paddleW / 2
        if leftHeld  { paddleX = max(half, paddleX - paddleSpeed * dt) }
        if rightHeld { paddleX = min(Self.W - half, paddleX + paddleSpeed * dt) }
    }

    // MARK: - Controls

    func applyKeyMovement(dt: CGFloat) {
        guard phase == .playing else { return }
        let half = paddleW / 2
        if leftHeld  { paddleX = max(half, paddleX - paddleSpeed * dt) }
        if rightHeld { paddleX = min(Self.W - half, paddleX + paddleSpeed * dt) }
    }

    func spacePressed() {
        NSApp.activate(ignoringOtherApps: true)
        switch phase {
        case .idle:     phase = .playing
        case .playing:  phase = .paused
        case .paused:   phase = .playing
        case .lifeLost: placeBall(); phase = .playing
        case .gameOver: reset(keepHi: true); phase = .playing
        default: break
        }
    }

    func startGame() {
        NSApp.activate(ignoringOtherApps: true)
        guard phase == .idle || phase == .gameOver else { return }
        if phase == .gameOver { reset(keepHi: true) }
        phase = .playing
    }

    func pauseToggle() {
        if phase == .playing { phase = .paused }
        else if phase == .paused { phase = .playing }
    }

    // MARK: - Game Loop (called every ~1/60s)

    func update() {
        // Age popups
        popups = popups.compactMap { p in
            var pp = p; pp.age += 0.025
            return pp.age < 1.0 ? pp : nil
        }

        // Decay flash
        if screenFlash > 0 { screenFlash = max(0, screenFlash - 0.06) }

        // Age brick flashes
        for i in bricks.indices where bricks[i].flashAge > 0 {
            bricks[i].flashAge = max(0, bricks[i].flashAge - 0.12)
        }

        guard phase == .playing else { return }

        // ── Move ball ───────────────────────────────────────────
        if frameCount % 2 == 0 { // Record trail every other frame at 120fps
            trail.append(ballPos)
            if trail.count > 8 { trail.removeFirst() }
        }

        var nx = ballPos.x + ballVel.x
        var ny = ballPos.y + ballVel.y

        // ── Wall bounces ─────────────────────────────────────────
        if nx - ballR <= 0 { nx = ballR; ballVel.x = abs(ballVel.x) }
        if nx + ballR >= Self.W { nx = Self.W - ballR; ballVel.x = -abs(ballVel.x) }
        if ny - ballR <= 0 { ny = ballR; ballVel.y = abs(ballVel.y) }

        // ── Paddle ───────────────────────────────────────────────
        let pRect = CGRect(x: paddleX - paddleW/2, y: paddleY, width: paddleW, height: paddleH)
        if ballVel.y > 0,
           ny + ballR >= pRect.minY,
           ny - ballR <= pRect.maxY + 2,
           nx >= pRect.minX - 4,
           nx <= pRect.maxX + 4 {

            ny = pRect.minY - ballR
            let hitFrac = (nx - pRect.midX) / (paddleW / 2)  // -1…1
            let spd = sqrt(ballVel.x*ballVel.x + ballVel.y*ballVel.y)
            let angle = Double(hitFrac) * 60 * .pi / 180
            ballVel.x = CGFloat(sin(angle)) * spd
            ballVel.y = -abs(ballVel.y)
            combo = 0
            trail = []
        }

        // ── Bottom (die) ─────────────────────────────────────────
        if ny - ballR > Self.H {
            lives -= 1
            combo = 0
            trail = []
            if lives <= 0 {
                saveHiScore()
                phase = .gameOver
            } else {
                phase = .lifeLost
                // Auto-resume after 1.5s so ball resets
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard self.phase == .lifeLost else { return }
                    self.placeBall()
                    self.phase = .playing
                }
            }
            ballPos = CGPoint(x: nx, y: Self.H + 20)
            return
        }

        ballPos = CGPoint(x: nx, y: ny)

        // ── Brick collisions ─────────────────────────────────────
        let bRect = CGRect(x: nx - ballR, y: ny - ballR, width: ballR*2, height: ballR*2)
        for i in bricks.indices {
            guard bricks[i].alive else { continue }
            let br = brickRect(col: bricks[i].col, row: bricks[i].row)
            guard bRect.intersects(br) else { continue }

            // Destroy
            bricks[i].alive = false
            bricks[i].flashAge = 1.0
            combo += 1

            let mult = max(1, combo / 4)
            let pts  = rowPoints[bricks[i].row] * mult
            score   += pts
            saveHiScore()
            screenFlash = min(1, screenFlash + 0.15)

            popups.append(ScorePopup(
                text: combo > 4 ? "×\(mult) \(pts)!" : "+\(pts)",
                pos: CGPoint(x: br.midX, y: br.midY)
            ))

            // Bounce direction
            let overL = bRect.maxX - br.minX
            let overR = br.maxX   - bRect.minX
            let overT = bRect.maxY - br.minY
            let overB = br.maxY   - bRect.minY
            if min(overL, overR) < min(overT, overB) {
                ballVel.x = -ballVel.x
            } else {
                ballVel.y = -ballVel.y
            }
            break
        }

        // ── Level complete ───────────────────────────────────────
        if bricks.allSatisfy({ !$0.alive }) {
            level    += 1
            speedMul  = min(speedMul + 0.08, 1.6)
            phase     = .levelUp
            popups.removeAll()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard self.phase == .levelUp else { return }
                self.buildBricks()
                self.placeBall()
                self.phase = .playing
            }
        }
    }

    private func saveHiScore() {
        if score > hiScore {
            hiScore = score
            UserDefaults.standard.set(hiScore, forKey: "notchBreaker.hi")
        }
    }
}

// MARK: - Main View

struct NotchBreakoutView: View {

    @StateObject private var game = BreakoutEngine()

    // 120fps game tick for buttery smooth physics (1/120 s ≈ 8.33 ms)
    private let ticker = Timer.publish(every: 1/120, on: .main, in: .common).autoconnect()
    private let dt: CGFloat = 1.0 / 120.0

    @State private var keyMonitorDown: Any? = nil
    @State private var keyMonitorUp:   Any? = nil

    var body: some View {
        ZStack {

            // ── Game Canvas ──────────────────────────────────────
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    drawBackground(&ctx, size: size)
                    drawTrail(&ctx)
                    drawBricks(&ctx)
                    drawBall(&ctx)
                    drawPaddle(&ctx)
                    drawPopups(&ctx)
                    if game.screenFlash > 0 {
                        ctx.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.white.opacity(Double(game.screenFlash) * 0.12))
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { game.spacePressed() }

            // ── Overlay screens ──────────────────────────────────
            switch game.phase {
            case .idle:
                IdleOverlay()
            case .paused:
                PausedOverlay(lives: game.lives)
            case .lifeLost:
                LifeLostOverlay(lives: game.lives)
            case .levelUp:
                LevelUpOverlay(level: game.level)
            case .gameOver:
                GameOverOverlay(score: game.score, hiScore: game.hiScore)
            default:
                EmptyView()
            }
            
            // HUD (Lives, Score, Level) mapped into top bar
            if game.phase == .playing || game.phase == .paused {
                VStack {
                    HStack(alignment: .center, spacing: 12) {
                        Text("\(game.score)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        if game.level > 1 {
                            Text("LVL \(game.level)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(Color(hue: 0.14, saturation: 0.8, brightness: 1.0).opacity(0.7))
                        }
                        
                        Text(String(repeating: "♥ ", count: game.lives).trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 16))
                            .foregroundColor(Color(hue: 0.97, saturation: 0.85, brightness: 1.0).opacity(0.8))
                        
                        Text("BEST: \(game.hiScore)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            
                        Spacer()
                    }
                    .padding(.leading, 45) // Align with where icons were
                    .offset(y: -35) // Move into the top bar area
                    Spacer()
                }
            }

        }
        .frame(width: BreakoutEngine.W, height: BreakoutEngine.H)
        .onReceive(ticker) { _ in
            game.applyKeyMovement(dt: dt)
            game.update()
        }
        .onAppear  { setupKeyMonitor() }
        .onDisappear { tearDownKeyMonitor(); game.phase = .paused }
    }

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        // Ensure the app has focus so spacebar and arrow keys work globally
        NSApp.activate(ignoringOtherApps: true)
        
        keyMonitorDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event, down: true)
            return event
        }
        keyMonitorUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            handleKey(event, down: false)
            return event
        }
    }

    private func tearDownKeyMonitor() {
        if let m = keyMonitorDown { NSEvent.removeMonitor(m); keyMonitorDown = nil }
        if let m = keyMonitorUp   { NSEvent.removeMonitor(m); keyMonitorUp   = nil }
    }

    private func handleKey(_ event: NSEvent, down: Bool) {
        switch event.keyCode {
        case 123: game.leftHeld  = down   // ← left arrow
        case 124: game.rightHeld = down   // → right arrow
        case 49 where down:               // Space bar — only on key-down
            game.spacePressed()
        default: break
        }
    }

    // MARK: - Close

    private func closeGame() {
        game.leftHeld  = false
        game.rightHeld = false
        game.phase = .paused
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.4)) {
            NotchState.shared.isHovering = false
            NotchState.shared.isExpanded = false
        }
    }

    // MARK: - Drawing

    private func drawBackground(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

        // Subtle grid scanlines
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                with: .color(.white.opacity(0.025))
            )
            y += 4
        }
    }

    private func drawTrail(_ ctx: inout GraphicsContext) {
        for (i, pos) in game.trail.enumerated() {
            let alpha = CGFloat(i + 1) / CGFloat(game.trail.count) * 0.4
            let r = game.ballR * CGFloat(i + 1) / CGFloat(game.trail.count) * 0.8
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r*2, height: r*2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }

    private func drawBricks(_ ctx: inout GraphicsContext) {
        for brick in game.bricks {
            guard brick.alive || brick.flashAge > 0 else { continue }
            let rect  = game.brickRect(col: brick.col, row: brick.row)
            let color = game.rowColors[brick.row]
            let alpha = brick.alive ? 1.0 : brick.flashAge

            let cornerRadius: CGFloat = 2.5
            let rPath = Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: cornerRadius)

            // Glow
            var gCtx = ctx
            gCtx.addFilter(.blur(radius: 4))
            gCtx.fill(rPath, with: .color(color.opacity(0.6 * alpha)))

            // Body gradient (modern glassmorphism)
            let grad = Gradient(colors: [
                color.opacity(alpha * 0.95),
                color.opacity(alpha * 0.4)
            ])
            ctx.fill(rPath, with: .linearGradient(
                grad,
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.minX, y: rect.maxY)
            ))

            // Inner stroke for glassy edge
            ctx.stroke(rPath, with: .color(.white.opacity(0.3 * alpha)), lineWidth: 0.5)

            // Top highlight for 3D bevel
            ctx.fill(
                Path(roundedRect: CGRect(x: rect.minX + 1, y: rect.minY + 1, width: rect.width - 2, height: 1.5), cornerRadius: 1),
                with: .color(Color.white.opacity(0.5 * alpha))
            )
        }
    }

    private func drawBall(_ ctx: inout GraphicsContext) {
        guard game.phase != .idle else { return }
        let pos  = game.ballPos
        let r    = game.ballR
        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r*2, height: r*2)

        // Outer glow
        var g2 = ctx
        g2.addFilter(.blur(radius: 7))
        g2.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(.white.opacity(0.6)))

        // Inner glow
        var g1 = ctx
        g1.addFilter(.blur(radius: 3))
        g1.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)))

        // Core
        ctx.fill(Path(ellipseIn: rect), with: .color(.white))
    }

    private func drawPaddle(_ ctx: inout GraphicsContext) {
        let rect = CGRect(
            x: game.paddleX - game.paddleW/2,
            y: game.paddleY,
            width: game.paddleW,
            height: game.paddleH
        )
        let path = RoundedRectangle(cornerRadius: 3).path(in: rect)

        // Glow
        var gCtx = ctx
        gCtx.addFilter(.blur(radius: 5))
        gCtx.fill(path, with: .color(Color(hue: 0.57, saturation: 0.9, brightness: 1.0).opacity(0.7)))

        // Body — gradient from cyan → blue
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [
                Color(hue: 0.52, saturation: 0.7, brightness: 1.0),
                Color(hue: 0.62, saturation: 0.9, brightness: 0.9)
            ]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint:   CGPoint(x: rect.maxX, y: rect.minY)
        ))

        // Top shine
        ctx.fill(
            Path(CGRect(x: rect.minX + 2, y: rect.minY + 1, width: rect.width - 4, height: 1.5)),
            with: .color(.white.opacity(0.5))
        )
    }

    private func drawHUD(_ ctx: inout GraphicsContext, size: CGSize) {
        // Score — top left
        let scoreText = Text("SCORE \(game.score)")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
        ctx.draw(scoreText, at: CGPoint(x: 10, y: 2), anchor: .topLeading)

        // Hi-Score — top center
        if game.hiScore > 0 {
            let hiText = Text("BEST \(game.hiScore)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
            ctx.draw(hiText, at: CGPoint(x: size.width/2, y: 2), anchor: .top)
        }

        // Lives — top right (hearts)
        let livesText = Text(String(repeating: "♥ ", count: game.lives).trimmingCharacters(in: .whitespaces))
            .font(.system(size: 9, weight: .black))
            .foregroundColor(Color(hue: 0.97, saturation: 0.85, brightness: 1.0).opacity(0.8))
        ctx.draw(livesText, at: CGPoint(x: size.width - 8, y: 2), anchor: .topTrailing)

        // Level badge
        if game.level > 1 {
            let lvlText = Text("LVL \(game.level)")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(Color(hue: 0.14, saturation: 0.8, brightness: 1.0).opacity(0.7))
            ctx.draw(lvlText, at: CGPoint(x: size.width/2, y: size.height - 2), anchor: .bottomLeading)
        }
    }

    private func drawPopups(_ ctx: inout GraphicsContext) {
        for popup in game.popups {
            let alpha  = 1.0 - popup.age
            let yOff   = popup.age * 22
            let pos    = CGPoint(x: popup.pos.x, y: popup.pos.y - yOff)
            let scale  = 0.7 + 0.5 * min(1, popup.age * 4)

            var pCtx = ctx
            pCtx.opacity = alpha
            pCtx.scaleBy(x: scale, y: scale)

            let label = Text(popup.text)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.white)

            let scaledPos = CGPoint(
                x: pos.x / scale,
                y: pos.y / scale
            )
            pCtx.draw(label, at: scaledPos, anchor: .center)
        }
    }
}

// MARK: - Overlay Views

private struct IdleOverlay: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 4) {
            Text("NOTCH BREAKER")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.57, saturation: 0.8, brightness: 1.0),
                            Color(hue: 0.36, saturation: 0.8, brightness: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hue: 0.57, saturation: 0.9, brightness: 1.0), radius: 8)

            Text("PRESS SPACE TO START")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(pulse ? 0.85 : 0.3))
                .animation(.easeInOut(duration: 0.7).repeatForever(), value: pulse)

            Text("← → MOVE PADDLE   SPACE PAUSE")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.55))
        .onAppear { pulse = true }
    }
}

private struct PausedOverlay: View {
    let lives: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("PAUSED")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Text("CLICK TO RESUME")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
    }
}

private struct LevelUpOverlay: View {
    let level: Int
    @State private var scale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: 2) {
            Text("LEVEL \(level)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.14, saturation: 0.85, brightness: 1.0),
                            Color(hue: 0.36, saturation: 0.85, brightness: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hue: 0.14, saturation: 0.9, brightness: 1.0), radius: 10)
                .scaleEffect(scale)
            Text("GET READY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.7))
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
    }
}

private struct GameOverOverlay: View {
    let score:   Int
    let hiScore: Int
    @State private var appear = false

    var body: some View {
        VStack(spacing: 3) {
            Text("GAME OVER")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(Color(hue: 0.97, saturation: 0.85, brightness: 1.0))
                .shadow(color: Color(hue: 0.97, saturation: 0.9, brightness: 1.0), radius: 8)

            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("SCORE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                if score >= hiScore && score > 0 {
                    Text("NEW BEST!")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hue: 0.14, saturation: 0.9, brightness: 1.0))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hue: 0.14, saturation: 0.9, brightness: 0.3)))
                } else {
                    VStack(spacing: 0) {
                        Text("\(hiScore)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Text("BEST")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            Text("CLICK TO RETRY")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.75))
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { appear = true }
        }
    }
}

private struct LifeLostOverlay: View {
    let lives: Int
    @State private var scale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: 4) {
            Text(String(repeating: "♥ ", count: lives).trimmingCharacters(in: .whitespaces))
                .font(.system(size: 32, weight: .black))
                .foregroundColor(Color(hue: 0.97, saturation: 0.85, brightness: 1.0))
                .shadow(color: Color(hue: 0.97, saturation: 0.9, brightness: 1.0), radius: 10)
                .scaleEffect(scale)
            
            Text("GET READY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.65))
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.0
            }
        }
    }
}

