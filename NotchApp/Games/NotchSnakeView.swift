import SwiftUI
import Combine

class SnakeGame: ObservableObject {
    @Published var phase: BreakoutPhase = .idle
    @Published var score = 0
    @Published var highScore = UserDefaults.standard.integer(forKey: "SnakeHighScore")
    
    struct Point: Equatable {
        var x: Int
        var y: Int
    }
    
    @Published var snake: [Point] = []
    @Published var apple: Point = Point(x: 0, y: 0)
    
    enum Direction { case up, down, left, right }
    var direction: Direction = .right
    var nextDirection: Direction = .right
    
    let cols = 64
    let rows = 12
    let cellSize: CGFloat = 10
    
    var frameCount = 0
    var speed: Int = 10 // moves every 10 frames
    
    func reset() {
        snake = [
            Point(x: cols/2, y: rows/2),
            Point(x: cols/2 - 1, y: rows/2),
            Point(x: cols/2 - 2, y: rows/2)
        ]
        direction = .right
        nextDirection = .right
        score = 0
        speed = 10
        frameCount = 0
        spawnApple()
        phase = .playing
    }
    
    func spawnApple() {
        var p = Point(x: Int.random(in: 0..<cols), y: Int.random(in: 0..<rows))
        while snake.contains(p) || isCorner(p) {
            p = Point(x: Int.random(in: 0..<cols), y: Int.random(in: 0..<rows))
        }
        apple = p
    }
    
    private func isCorner(_ p: Point) -> Bool {
        return (p.x == 0 && p.y == 0) || 
               (p.x == cols - 1 && p.y == 0) ||
               (p.x == 0 && p.y == rows - 1) || 
               (p.x == cols - 1 && p.y == rows - 1)
    }
    
    func changeDirection(_ newDir: Direction) {
        if phase == .idle || phase == .gameOver {
            reset()
            return
        }
        
        switch (direction, newDir) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            break
        default:
            nextDirection = newDir
        }
    }
    
    func update() {
        guard phase == .playing else { return }
        
        frameCount += 1
        if frameCount % speed != 0 { return }
        
        direction = nextDirection
        
        var head = snake[0]
        switch direction {
        case .up: head.y -= 1
        case .down: head.y += 1
        case .left: head.x -= 1
        case .right: head.x += 1
        }
        
        // Wall collision
        if head.x < 0 || head.x >= cols || head.y < 0 || head.y >= rows {
            die()
            return
        }
        
        // Self collision
        if snake.contains(head) {
            die()
            return
        }
        
        snake.insert(head, at: 0)
        
        // Apple
        if head == apple {
            score += 1
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "SnakeHighScore")
            }
            if speed > 4 { speed -= 1 } // gets slightly faster
            spawnApple()
        } else {
            snake.removeLast()
        }
    }
    
    private func die() {
        phase = .gameOver
    }
}

struct NotchSnakeView: View {
    @StateObject private var game = SnakeGame()
    @State private var keyMonitorDown: Any?
    
    private let ticker = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Grid and Snake Engine
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    Canvas { ctx, size in
                        let gridWidth = CGFloat(game.cols) * game.cellSize
                        let gridHeight = CGFloat(game.rows) * game.cellSize
                        
                        let offsetX = (size.width - gridWidth) / 2
                        let offsetY = (size.height - gridHeight) / 2
                        
                        // Draw Neon Border
                        let borderRect = CGRect(x: offsetX - 2, y: offsetY - 6, width: gridWidth + 4, height: gridHeight + 10)
                        let borderPath = Path(roundedRect: borderRect, cornerRadius: 16) // matches notch style
                        
                        var borderGlow = ctx
                        borderGlow.addFilter(.blur(radius: 6))
                        borderGlow.stroke(borderPath, with: .color(.green.opacity(0.8)), lineWidth: 4)
                        ctx.stroke(borderPath, with: .color(Color(hue: 0.35, saturation: 0.9, brightness: 1.0)), lineWidth: 1.5)
                        
                        // Draw Apple (Neon glowing red orb)
                        let appleRect = CGRect(x: offsetX + CGFloat(game.apple.x) * game.cellSize,
                                               y: offsetY + CGFloat(game.apple.y) * game.cellSize,
                                               width: game.cellSize, height: game.cellSize)
                        let applePath = Path(ellipseIn: appleRect.insetBy(dx: 1, dy: 1))
                        
                        var appleGlow = ctx
                        appleGlow.addFilter(.blur(radius: 4))
                        appleGlow.fill(applePath, with: .color(.red.opacity(0.8)))
                        ctx.fill(applePath, with: .color(.red))
                        ctx.fill(Path(ellipseIn: CGRect(x: appleRect.minX + 3, y: appleRect.minY + 2, width: 3, height: 2)), with: .color(.white.opacity(0.7)))
                        
                        // Draw Snake (Glassmorphism blocks)
                        for (i, p) in game.snake.enumerated() {
                            let rect = CGRect(x: offsetX + CGFloat(p.x) * game.cellSize,
                                              y: offsetY + CGFloat(p.y) * game.cellSize,
                                              width: game.cellSize, height: game.cellSize)
                            
                            let path = Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2)
                            
                            // Head is slightly brighter green
                            let baseColor = i == 0 ? Color(hue: 0.35, saturation: 0.9, brightness: 1.0) : Color(hue: 0.40, saturation: 0.8, brightness: 0.8)
                            
                            let grad = Gradient(colors: [baseColor, baseColor.opacity(0.5)])
                            ctx.fill(path, with: .linearGradient(grad, startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                            
                            // Inner glassy stroke
                            ctx.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                }
                Spacer()
            }
            
            // Overlays
            if game.phase == .idle {
                VStack(spacing: 4) {
                    Text("SNAKE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .green, radius: 8)
                    Text("PRESS ARROWS TO PLAY")
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
                    Text("PRESS ARROWS TO RESTART")
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
            if game.phase == .idle || game.phase == .gameOver {
                game.reset()
            }
        }
    }
    
    private func setupKeyMonitor() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: { $0.isVisible }) { win.makeKey() }
        
        keyMonitorDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 126: game.changeDirection(.up); return nil
            case 125: game.changeDirection(.down); return nil
            case 123: game.changeDirection(.left); return nil
            case 124: game.changeDirection(.right); return nil
            default: break
            }
            return event
        }
    }
}
