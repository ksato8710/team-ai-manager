import SwiftUI

struct AIInsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAnalyzing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("AI Insights")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("AI-powered analysis and recommendations for your team")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: runAnalysis) {
                    HStack(spacing: 4) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(isAnalyzing ? "Analyzing..." : "Run Analysis")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnalyzing)
            }
            .padding(24)

            Divider()

            if appState.aiService.insights.isEmpty {
                ContentUnavailableView(
                    "No Insights Yet",
                    systemImage: "brain",
                    description: Text("Click 'Run Analysis' to generate AI-powered insights about your team's workload, skill gaps, and staffing recommendations.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.aiService.insights) { insight in
                            InsightCard(insight: insight) {
                                try? appState.aiService.dismissInsight(insight)
                            } onAction: {
                                try? appState.aiService.actionInsight(insight)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func runAnalysis() {
        isAnalyzing = true
        Task {
            do {
                _ = try await appState.aiService.analyzeWorkload()
                _ = try await appState.aiService.analyzeSkillGaps()
            } catch {
                print("Analysis error: \(error)")
            }
            isAnalyzing = false
        }
    }
}

struct InsightCard: View {
    let insight: AIInsight
    let onDismiss: () -> Void
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: insight.insightType.icon)
                    .font(.title3)
                    .foregroundStyle(insightColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.insightType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(insight.title)
                        .font(.headline)
                }
                Spacer()
                ConfidenceBadge(confidence: insight.confidence)
            }

            Text(insight.content)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            HStack {
                Button("Dismiss") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Take Action") { onAction() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    var insightColor: Color {
        switch insight.insightType {
        case .workloadAlert, .projectRisk: return .orange
        case .skillGap: return .red
        case .staffingSuggestion, .growthOpportunity: return .green
        case .collaborationPattern, .knowledgeConnection: return .blue
        case .performanceTrend: return .purple
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor.opacity(0.1))
            .foregroundStyle(confidenceColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    var confidenceColor: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
}
