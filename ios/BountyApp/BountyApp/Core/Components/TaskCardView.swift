import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.bountyText)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.bountyDanger)
                        Text(task.targetAddr)
                            .font(.system(size: 13))
                            .foregroundColor(.bountyTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                BeansBadge(beans: task.bountyBeans, fontSize: 18)
            }

            HStack {
                StatusBadge(status: task.status)
                Spacer()
                if let distance = task.distance {
                    Text("".distanceDisplay(distance))
                        .font(.system(size: 12))
                        .foregroundColor(.bountyInfo)
                }
            }

            HStack(spacing: 14) {
                Label(String(format: L10n.taskDistanceKm, task.radius / 1000), systemImage: "scope")
                    .font(.system(size: 12))
                    .foregroundColor(.bountyTextSecondary)
                Label(String(format: L10n.taskTimeMin, task.timeLimit), systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.bountyTextSecondary)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
