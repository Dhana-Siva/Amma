import ActivityKit
import WidgetKit
import SwiftUI

/// Renders the "return to Amma" Live Activity — a Lock Screen banner plus
/// the Dynamic Island's compact/expanded/minimal presentations. Started
/// by ReturnActivityService in the main app right when it hands off to
/// WhatsApp/Phone, and ended once the parent comes back to Amma.
struct ReturnLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReturnActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(.pink)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(.pink)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.message)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.pink)
            } compactTrailing: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.pink)
            } minimal: {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.pink)
            }
            .widgetURL(URL(string: "amma://return"))
            .keylineTint(.pink)
        }
    }

    private func lockScreenView(context: ActivityViewContext<ReturnActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 2) {
                Text("Amma")
                    .font(.headline)
                Text(context.state.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title)
                .foregroundStyle(.pink)
        }
        .padding()
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(.primary)
        .widgetURL(URL(string: "amma://return"))
    }
}
