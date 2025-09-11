import SwiftUI
import WebKit

struct MainChatView: View {
    @State private var selectedService: AIService
    @State private var isLoading = true
    let services: [AIService]
    
    init(services: [AIService] = getAvailableServices()) {
        self.services = services
        // Set initial selected service
        _selectedService = State(initialValue: services.first!)
    }
    
    // Initialize with a specific service
    init(initialService: AIService, services: [AIService] = getAvailableServices()) {
        self.services = services
        _selectedService = State(initialValue: initialService)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Pro upgrade prompt
            ProUpgradePrompt()
            // Pro splash screen
            ProSplashView()
            // Pro upgrade banner
            ProUpgradeBanner()
            // Pro stats view
            ProStatsView()
            // Pro analytics view
            ProAnalyticsView()
            // Pro usage limit view
            ProUsageLimitView()
            // Pro theme view
            ProThemeView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro customization view
            ProCustomizationView()
            // Pro automation view
            ProAutomationView()
            // Pro advanced analytics view
            ProAdvancedAnalyticsView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro export view
            ProExportView()
            // Pro backup view
            ProBackupView()
            // Pro API view
            ProAPIView()
            // Pro security view
            ProSecurityView()
            // Pro performance view
            ProPerformanceView()
            // Pro collaboration view
            ProCollaborationView()
            // Pro integration view
            ProIntegrationView()
            // Pro customization view
            ProCustomizationView()
            // Pro automation view
            ProAutomationView()
            // Pro advanced analytics view
            ProAdvancedAnalyticsView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro customization view
            ProCustomizationView()
            // Pro automation view
            ProAutomationView()
            // Pro advanced analytics view
            ProAdvancedAnalyticsView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro automation view
            ProAutomationView()
            // Pro advanced analytics view
            ProAdvancedAnalyticsView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro advanced analytics view
            ProAdvancedAnalyticsView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro integration view
            ProIntegrationView()
            // Pro customization view
            ProCustomizationView()
            // Pro automation view
            ProAutomationView()
            // Pro advanced analytics view
            ProAdvancedAnalyticsView()
            // Pro sync view
            ProSyncView()
            // Pro priority view
            ProPriorityView()
            // Pro enterprise view
            ProEnterpriseView()
            // Pro compliance view
            ProComplianceView()
            // Pro monitoring view
            ProMonitoringView()
            // Pro reporting view
            ProReportingView()
            // Pro scaling view
            ProScalingView()
            // Pro optimization view
            ProOptimizationView()
            // Pro testing view
            ProTestingView()
            // Pro deployment view
            ProDeploymentView()
            // Pro maintenance view
            ProMaintenanceView()
            // Pro support view
            ProSupportView()
            // Pro training view
            ProTrainingView()
            // Pro consulting view
            ProConsultingView()
            // Pro migration view
            ProMigrationView()
            // Pro integration view
            ProIntegrationView()
            // Top bar with model selector
            HStack {
                Text("AppleAi Pro")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Model selector dropdown
                ServicePickerView(selectedService: $selectedService, services: services)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Model indicator bar
            HStack {
                Image(selectedService.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
                Text(selectedService.name)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Add file upload button
                Button(action: {
                    WebViewCache.shared.triggerFileUpload(for: selectedService)
                }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing, 8)
                .help("Attach files")
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(selectedService.color)
            
            // Web view for the selected service - use PersistentWebView instead
            WebViewWithWatermark(service: selectedService, isLoading: $isLoading)
                // Remove the .id modifier to preserve WebView state
        }
    }
}

// Preview for SwiftUI Canvas
struct MainChatView_Previews: PreviewProvider {
    static var previews: some View {
        MainChatView()
            .frame(width: 800, height: 600)
    }
} 