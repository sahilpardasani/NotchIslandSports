import SwiftUI

// MARK: - SwiftUI Preview Provider Helpers

struct NotchContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Collapsed Notch view (Cricket)
            previewContainer(expanded: false, activeSport: .cricket)
                .previewDisplayName("Collapsed (Cricket)")
            
            // Collapsed Notch view (Tennis)
            previewContainer(expanded: false, activeSport: .tennis)
                .previewDisplayName("Collapsed (Tennis)")
            
            // Expanded Cricket
            previewContainer(expanded: true, activeSport: .cricket)
                .previewDisplayName("Expanded (Cricket)")
            
            // Expanded Tennis
            previewContainer(expanded: true, activeSport: .tennis)
                .previewDisplayName("Expanded (Tennis)")
            
            // Expanded NFL
            previewContainer(expanded: true, activeSport: .nfl)
                .previewDisplayName("Expanded (NFL)")
            
            // Expanded Soccer
            previewContainer(expanded: true, activeSport: .soccer)
                .previewDisplayName("Expanded (Soccer)")
            
            // Expanded Volleyball
            previewContainer(expanded: true, activeSport: .volleyball)
                .previewDisplayName("Expanded (Volleyball)")
        }
        .preferredColorScheme(.dark)
    }
    
    @MainActor
    private static func previewContainer(expanded: Bool, activeSport: SportType) -> some View {
        let hoverState = HoverState()
        hoverState.isHovered = expanded
        
        let dataManager = SportsDataManager()
        let mocks = MockDataProvider.getMockMatches()
        dataManager.allMatches = mocks
        
        // Find the match for this sport
        if let match = mocks.first(where: { $0.sportType == activeSport }) {
            dataManager.activeMatch = match
        }
        
        return NotchContentView(hoverState: hoverState, dataManager: dataManager)
            .frame(width: expanded ? 400 : 340, height: expanded ? 360 : 36)
            .padding()
            .background(Color.black.opacity(0.85))
    }
}
