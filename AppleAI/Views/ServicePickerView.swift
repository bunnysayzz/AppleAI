import SwiftUI

struct ServicePickerView: View {
    @Binding var selectedService: AIService
    let services: [AIService]
    @ObservedObject var proManager = ProManager.shared
    
    var body: some View {
        Picker("", selection: $selectedService) {
            ForEach(services) { service in
                HStack {
                    Image(service.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(service.color)
                    
                    Text(service.name)
                    
                    if service.isProOnly && !proManager.isProUser {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                    }
                }
                .tag(service)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .frame(width: 150)
    }
}
