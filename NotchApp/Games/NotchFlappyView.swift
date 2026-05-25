import SwiftUI
import Combine

class FlappyGame: ObservableObject {
    @Published var phase: BreakoutPhase = .idle
    @Published var score = 0
    @Published var highScore = UserDefaults.standard.integer(forKey: "FlappyHighScore")
    
    // Bird State
    @Published var birdY: CGFloat = 70
    var birdVelocity: CGFloat = 0
    let birdX: CGFloat = 100
    let birdRadius: CGFloat = 12
    
    // Physics
    let gravity: CGFloat = 0.2
    let jumpForce: CGFloat = -4.0
    
    // Pipe State
    struct Pipe {
        var x: CGFloat
        var gapY: CGFloat
        let gapSize: CGFloat = 85
        let width: CGFloat = 35
        var passed = false
    }
    @Published var pipes: [Pipe] = []
    
    let pipeSpeed: CGFloat = 1.8
    let spawnInterval: Int = 150 // frames
    var frameCount = 0
    
    let width: CGFloat = 600
    let height: CGFloat = 150
    
    func reset() {
        birdY = height / 2
        birdVelocity = 0
        pipes = []
        score = 0
        frameCount = 0
        phase = .playing
    }
    
    func flap() {
        if phase == .idle || phase == .gameOver {
            reset()
            birdVelocity = jumpForce // Instantly jump when starting
        } else if phase == .playing {
            birdVelocity = jumpForce
        }
    }
    
    func update() {
        guard phase == .playing else { return }
        
        // Physics
        birdVelocity += gravity
        birdY += birdVelocity
        
        // Collision (Floor/Ceiling)
        if birdY > height - birdRadius {
            birdY = height - birdRadius
            die()
        } else if birdY < birdRadius {
            birdY = birdRadius
            birdVelocity = 0
        }
        
        // Pipes
        frameCount += 1
        if frameCount % spawnInterval == 0 {
            let gapY = CGFloat.random(in: 45...(height - 45))
            pipes.append(Pipe(x: width + 50, gapY: gapY))
        }
        
        let birdRect = CGRect(x: birdX - birdRadius + 4, y: birdY - birdRadius + 4, width: birdRadius * 2 - 8, height: birdRadius * 2 - 8)
        
        for i in (0..<pipes.count).reversed() {
            pipes[i].x -= pipeSpeed
            
            let p = pipes[i]
            let topPipe = CGRect(x: p.x, y: 0, width: p.width, height: p.gapY - p.gapSize / 2)
            let bottomPipe = CGRect(x: p.x, y: p.gapY + p.gapSize / 2, width: p.width, height: height - (p.gapY + p.gapSize / 2))
            
            // Score
            if !p.passed && birdX > p.x + p.width {
                pipes[i].passed = true
                score += 1
                if score > highScore {
                    highScore = score
                    UserDefaults.standard.set(highScore, forKey: "FlappyHighScore")
                }
            }
            
            // Collision
            if birdRect.intersects(topPipe) || birdRect.intersects(bottomPipe) {
                die()
            }
            
            // Remove offscreen
            if p.x < -p.width {
                pipes.remove(at: i)
            }
        }
    }
    
    private func die() {
        phase = .gameOver
    }
}

struct NotchFlappyView: View {
    @StateObject private var game = FlappyGame()
    @State private var keyMonitorDown: Any?
    
    private let ticker = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Render Loop
            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    // Draw Flames at bottom (drawn FIRST so pipes overlay them)
                    let time = context.date.timeIntervalSinceReferenceDate
                    var flamePath = Path()
                    flamePath.move(to: CGPoint(x: -10, y: size.height + 50))
                    
                    for x in stride(from: 0, through: Double(size.width), by: 8.0) {
                        let wave1 = sin(x * 0.05 + time * 6) * 6
                        let wave2 = cos(x * 0.12 + time * 10) * 4
                        let h = 10 + wave1 + wave2
                        flamePath.addLine(to: CGPoint(x: CGFloat(x), y: size.height - CGFloat(h)))
                    }
                    flamePath.addLine(to: CGPoint(x: size.width + 10, y: size.height + 50))
                    flamePath.closeSubpath()
                    
                    var flameGlow = ctx
                    flameGlow.addFilter(.blur(radius: 6))
                    flameGlow.fill(flamePath, with: .color(.red.opacity(0.8)))
                    
                    ctx.fill(flamePath, with: .linearGradient(Gradient(colors: [.yellow, .red]), startPoint: CGPoint(x: 0, y: size.height - 15), endPoint: CGPoint(x: 0, y: size.height + 10)))
                    
                    // Draw Pipes
                    for p in game.pipes {
                        let topRect = CGRect(x: p.x, y: 0, width: p.width, height: p.gapY - p.gapSize / 2)
                        let bottomRect = CGRect(x: p.x, y: p.gapY + p.gapSize / 2, width: p.width, height: size.height - (p.gapY + p.gapSize / 2))
                        
                        let topPath = Path(roundedRect: topRect, cornerRadius: 6)
                        let botPath = Path(roundedRect: bottomRect, cornerRadius: 6)
                        
                        // Solid green pipe body
                        let grad = Gradient(colors: [Color.green, Color(hue: 0.35, saturation: 0.9, brightness: 0.4)])
                        ctx.fill(topPath, with: .linearGradient(grad, startPoint: CGPoint(x: topRect.minX, y: topRect.minY), endPoint: CGPoint(x: topRect.maxX, y: topRect.minY)))
                        ctx.fill(botPath, with: .linearGradient(grad, startPoint: CGPoint(x: bottomRect.minX, y: bottomRect.minY), endPoint: CGPoint(x: bottomRect.maxX, y: bottomRect.minY)))
                        
                        // Outer neon glow
                        var gCtx = ctx
                        gCtx.addFilter(.blur(radius: 4))
                        gCtx.fill(topPath, with: .color(.green))
                        gCtx.fill(botPath, with: .color(.green))
                        
                        // Inner glassy stroke
                        ctx.stroke(topPath, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                        ctx.stroke(botPath, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                    }
                }
            }
            
            // Draw Bird (Using SF Symbol inside standard SwiftUI overlay for better quality than Canvas drawing)
            Image(systemName: "bird.fill")
                .resizable()
                .scaledToFit()
                .frame(width: game.birdRadius * 2, height: game.birdRadius * 2)
                .foregroundColor(.yellow)
                .shadow(color: .orange.opacity(0.8), radius: 6)
                .rotationEffect(.degrees(Double(game.birdVelocity * 3))) // Rotate bird based on velocity
                .position(x: game.birdX, y: game.birdY)
            
            // Overlays
            if game.phase == .idle {
                VStack(spacing: 4) {
                    Text("FLAPPY BIRD")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .orange, radius: 8)
                    Text("PRESS SPACE TO FLAP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.6))
            } else if game.phase == .gameOver {
                VStack(spacing: 8) {
                    Text("GAME OVER")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .red, radius: 8)
                    Text("Score: \(game.score)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("PRESS SPACE TO RESTART")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.8))
            } else {
                VStack {
                    HStack(alignment: .center, spacing: 15) {
                        Text("\(game.score)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("BEST: \(game.highScore)")
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
        .onReceive(ticker) { _ in
            game.update()
        }
        .onAppear {
            setupKeyMonitor()
        }
        .onDisappear {
            if let m = keyMonitorDown { NSEvent.removeMonitor(m) }
        }
        .onTapGesture {
            NSApp.activate(ignoringOtherApps: true)
            if let win = NSApp.windows.first(where: { $0.isVisible }) { win.makeKey() }
            game.flap()
        }
    }
    
    private func setupKeyMonitor() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: { $0.isVisible }) { win.makeKey() }
        
        keyMonitorDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 { // Space
                game.flap()
                return nil // consume event
            }
            return event
        }
    }
}
