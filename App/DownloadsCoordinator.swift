// App-target file. Shared @Observable that polls Antra jobs for anything
// currently in-flight, so multiple screens (Search banner, AntraView) can
// react without each spinning up their own timer.
import SwiftUI
import GeetHubKit

@MainActor
@Observable
final class DownloadsCoordinator {
    /// Jobs whose status is `queued` or `running`. Progress is filled in
    /// (from the per-job status endpoint) on the poll cadence.
    private(set) var activeJobs: [AntraJob] = []

    private let client: SubsonicClient
    private var pollTimer: Timer?

    init(client: SubsonicClient) {
        self.client = client
        start()
    }

    // No deinit — the timer's [weak self] closure no-ops once we're released,
    // and Swift 6 strict concurrency disallows touching @MainActor state from
    // a nonisolated deinit anyway.

    func start() {
        Task { await refresh() }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        let all = (try? await client.antraJobs()) ?? []
        var active = all.filter { $0.status == "running" || $0.status == "queued" }
        if !active.isEmpty {
            await withTaskGroup(of: AntraJob?.self) { group in
                for j in active {
                    group.addTask { try? await self.client.antraJobStatus(id: j.id) }
                }
                for await updated in group {
                    if let updated,
                       let idx = active.firstIndex(where: { $0.id == updated.id }) {
                        active[idx] = updated
                    }
                }
            }
        }
        activeJobs = active
    }
}
