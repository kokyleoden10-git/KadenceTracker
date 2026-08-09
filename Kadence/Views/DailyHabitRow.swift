import SwiftUI

/// Three logical states per habit-per-day: not yet logged (neutral, no
/// judgment — you just haven't gotten to it), done, or explicitly not-done
/// (a deliberate honest entry, distinct from "not yet" — spec's
/// break_context prompt only makes sense for this state, per Power of
/// Habit's cue-tracking-on-breaks idea).
enum DailyLogState {
    case notLogged
    case done
    case notDone
}

struct DailyHabitRow: View {
    let habit: Habit
    let state: DailyLogState
    var onToggleDone: () -> Void
    var onMarkNotDone: () -> Void
    var onClear: () -> Void
    var onOpenDetail: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleDone) {
                checkbox
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Mark Done", action: onToggleDone)
                Button("Mark Not Done", action: onMarkNotDone)
                if state != .notLogged {
                    Button("Clear", role: .destructive, action: onClear)
                }
            }

            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(KadenceTheme.bodyFont(15))
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .strikethrough(state == .done, color: KadenceTheme.textMuted)

                    HStack(spacing: 6) {
                        Text(habit.tier == .anchor ? "Anchor" : "Practice")
                        if habit.direction == .reduce {
                            Text("\u{00B7} Reduce")
                        }
                    }
                    .font(KadenceTheme.bodyFont(11))
                    .foregroundStyle(KadenceTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(KadenceTheme.textMuted.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var checkbox: some View {
        switch state {
        case .notLogged:
            Circle()
                .stroke(KadenceTheme.color(for: habit.domain), lineWidth: 2)
                .frame(width: 26, height: 26)
        case .done:
            Circle()
                .fill(KadenceTheme.color(for: habit.domain))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KadenceTheme.bg)
                )
        case .notDone:
            Circle()
                .fill(KadenceTheme.surface)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(KadenceTheme.ariesEmber, lineWidth: 2))
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KadenceTheme.ariesEmber)
                )
        }
    }
}
