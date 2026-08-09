import SwiftUI

struct HabitRow: View {
    let habit: Habit
    var action: () -> Void
    var unarchiveAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(KadenceTheme.color(for: habit.domain))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(KadenceTheme.bodyFont(15))
                            .foregroundStyle(KadenceTheme.textPrimary)

                        HStack(spacing: 6) {
                            Text(habit.tier == .anchor ? "Anchor" : "Practice")
                            if habit.direction == .reduce {
                                Text("\u{00B7} Reduce")
                            }
                            if habit.streakCount > 0 {
                                Text("\u{00B7} \(habit.streakCount)\u{1F525}")
                            }
                        }
                        .font(KadenceTheme.bodyFont(11))
                        .foregroundStyle(KadenceTheme.textMuted)
                    }

                    Spacer()

                    if unarchiveAction == nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(KadenceTheme.textMuted.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            if let unarchiveAction {
                Button(action: unarchiveAction) {
                    Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(KadenceTheme.bodyFontSemibold(12))
                        .foregroundStyle(KadenceTheme.piscesTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
