import SwiftUI

struct ProThemeView: View {
    @ObservedObject var proManager = ProManager.shared
    @State private var selectedTheme = "Default"
    
    let themes = ["Default", "Dark", "Light", "Pro Dark", "Pro Light", "Pro Gradient"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 12))
                
                Text("Themes")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Picker("Theme", selection: $selectedTheme) {
                ForEach(themes, id: \.self) { theme in
                    HStack {
                        Text(theme)
                        
                        if theme.contains("Pro") && !proManager.isProUser {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 10))
                        }
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 120)
            
            if selectedTheme.contains("Pro") && !proManager.isProUser {
                Text("Pro themes require upgrade")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
