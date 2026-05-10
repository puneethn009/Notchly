import SwiftUI
import SwiftData

struct ScreenshotNamingView: View {
    let url: URL
    @State private var name: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text("NAME YOUR SCREENSHOT")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(1)
                    .padding(.top, 16)
                
                ZStack {
                    if let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 90) // Compact preview
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.5), radius: 10)
                    }
                }
                
                HStack(spacing: 10) {
                    TextField("Enter name...", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                        .focused($isFocused)
                        .onSubmit(save)
                    
                    Button(action: save) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                
                Button("Skip & use default") {
                    save()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .buttonStyle(.plain)
                .padding(.bottom, 20)
                
                Spacer()
            }
        }
        .onAppear {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            name = "Screenshot \(formatter.string(from: Date()))"
            
            // Short delay to ensure window is key before requesting focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
    
    private func save() {
        withAnimation(.spring(response: 0.3)) {
            ScreenshotMonitor.shared.finalizePendingScreenshot(withName: name)
        }
    }
}

