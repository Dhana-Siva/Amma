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
                        .symbolEffect(.pulse, options: .repeating)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(.pink)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("Amma")
                            .font(.system(size: 15, weight: .bold))
                        Text(context.state.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
            } compactLeading: {
                // .pulse keeps drawing the eye back to it for as long as
                // the activity is up, rather than sitting there quietly
                // and being easy to miss/forget about.
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.pink)
                    .symbolEffect(.pulse, options: .repeating)
            } compactTrailing: {
                // The compact pill is icon-only by default and easy to
                // mistake for some other app's activity — a short "Amma"
                // label makes it identifiable at a glance without opening
                // it.
                Text("Amma")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.pink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.pink)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .widgetURL(URL(string: "amma://return"))
            .keylineTint(.pink)
        }
    }

    private func lockScreenView(context: ActivityViewContext<ReturnActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.pink)
                .symbolEffect(.pulse, options: .repeating)
            VStack(alignment: .leading, spacing: 2) {
                Text("Amma")
                    .font(.system(.headline, weight: .heavy))
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
