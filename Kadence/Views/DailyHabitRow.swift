import SwiftUI

/// Three logical states per habit-per-day: not yet logged (neutral, no
/// judgment — you just haven't gotten to it), done, or explicitly not-done
/// (a deliberate honest entry, distinct from "not yet" — spec's
/// break_context prompt only makes sense for this state, per Power of
/// Habit's cue-tracking-on-breaks idea).
///
/// "Not done" is deliberately styled neutral, not alarming — no red, no X.
/// The whole point of "instrument, not judge" (spec §1) is that a skipped
/// day is a data point, not a failure, and the UI shouldn't visually
/// contradict that by making a miss look like an error state.
enum DailyLogState {
    case notLogged
    case done
    case notDone
}

struct DailyHabitRow: View {
    let habit: Habit
    let state: DailyLogState
    var onToggleDone: () -> Void
    var onOpenDetail: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleDone) {
                checkbox
            }
            .buttonStyle(.plain)

            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(KadenceTheme.bodyFont(15))
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .strikethrough(state == .done, color: KadenceTheme.textMuted)

                    HStack(spacing: 6) {
                        // Slightly more emphasis than the rest of the
                        // metadata line — the "Practices · important, not
                        // urgent" framing lives on the group header when
                        // sorted by tier (HomeView), so it'd be redundant
                        // to repeat in full on every single row.
                        Text(habit.tier == .anchor ? "Anchor" : "Practice")
                            .font(KadenceTheme.bodyFontSemibold(11))
                            .foregroundStyle(KadenceTheme.textMuted.opacity(0.95))
                        if habit.direction == .reduce {
                            Text("\u{00B7} Reduce")
                                .font(KadenceTheme.bodyFont(11))
                                .foregroundStyle(KadenceTheme.textMuted)
                        }
                    }

                    if let identity = habit.identityStatement, !identity.isEmpty {
                        Text("\u{201C}\(identity)\u{201D}")
                            .font(KadenceTheme.bodyFont(11))
                            .italic()
                            .foregroundStyle(KadenceTheme.piscesSeafoam.opacity(0.85))
                    }
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
                .stroke(KadenceTheme.textMuted, lineWidth: 2)
                .frame(width: 26, height: 26)
                .overlay(
                    Rectangle()
                        .fill(KadenceTheme.textMuted)
                        .frame(width: 10, height: 2)
                )
        }
    }
}
