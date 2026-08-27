// App-target file. Antra dashboard — paste a URL, pick folder/format, queue
// it as an Antra job. Live jobs list below.
import SwiftUI
import GeetHubKit

struct AntraView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    // URL input + queue controls
    @State private var urlText = ""
    @State private var format = "mp3"
    @State private var folder: String? = nil
    @State private var folders: [String] = []
    @State private var queuing = false
    @State private var toast: String?

    // Jobs list
    @State private var jobs: [AntraJob] = []
    @State private var isLoading = true
    @State private var pollTask: Task<Void, Never>?
    /// Per-job track breakdown, only populated for jobs currently visible in
    /// their expanded state (running jobs auto-expand; done ones are hidden
    /// until tapped).
    @State private var tracksByJob: [Int: [AntraTrack]] = [:]
    @State private var expandedJobs: Set<Int> = []

    // Common — most users of this app run YouTube-only sources, but leave the
    // knob exposed for the future.
    private let formatOptions = ["mp3", "flac", "alac", "opus", "wav"]

    private var sortedJobs: [AntraJob] { jobs.sorted { $0.id > $1.id } }
    private var canQueue: Bool {
        !queuing && !urlText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    queueCard
                    jobsCard
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 120)
            }
            .paperBackground()
            .refreshable { await refreshJobs() }
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) { toastView }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Downloader").retro(12, .semibold, tracking: 2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                }
            }
        }
        .task {
            await loadFolders()
            await refreshJobs()
            startPolling()
        }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Queue card

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox").foregroundStyle(Theme.accent)
                Text("Queue a download").retro(13, .semibold, tracking: 1.5)
            }

            // URL field with a paste helper.
            VStack(alignment: .leading, spacing: 6) {
                Text("URL").retro(10, .medium, color: Theme.graphite, tracking: 1)
                HStack(spacing: 8) {
                    TextField("https://…", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    if urlText.isEmpty {
                        Button {
                            if let s = UIPasteboard.general.string {
                                urlText = s.trimmingCharacters(in: .whitespaces)
                            }
                        } label: {
                            Text("Paste").retro(10, .semibold, color: Theme.accent, tracking: 1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { urlText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.graphite)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            }

            // Folder + Format side-by-side. Each Menu wraps a styled label so
            // the whole pill is the tap target (an overlaid Menu with an
            // invisible label doesn't receive gestures reliably).
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Folder").retro(10, .medium, color: Theme.graphite, tracking: 1)
                    Menu {
                        Button("Library root") { folder = nil }
                        if !folders.isEmpty { Divider() }
                        ForEach(folders, id: \.self) { f in
                            Button(f) { folder = f }
                        }
                    } label: {
                        pickerPill(text: folder ?? "Library root")
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Format").retro(10, .medium, color: Theme.graphite, tracking: 1)
                    Menu {
                        ForEach(formatOptions, id: \.self) { f in
                            Button(f.uppercased()) { format = f }
                        }
                    } label: {
                        pickerPill(text: format.uppercased())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: queue) {
                HStack(spacing: 8) {
                    if queuing {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Queue Download").retro(14, .semibold, color: .white, tracking: 2)
                    }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canQueue ? Theme.accent : Theme.graphite)
            }
            .disabled(!canQueue)
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    /// The visible pill used as a Menu label — the Menu itself handles taps.
    private func pickerPill(text: String) -> some View {
        HStack {
            Text(text).retro(12, .semibold, color: Theme.ink, tracking: 1).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2).foregroundStyle(Theme.graphite)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Theme.hairline, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Jobs list

    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(Theme.accent)
                Text("Recent jobs").retro(13, .semibold, tracking: 1.5)
                Spacer()
                if !jobs.isEmpty {
                    Text("\(jobs.count)").retro(10, .light, color: Theme.graphite, tracking: 1)
                }
            }

            if isLoading && jobs.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(40)
            } else if jobs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray").font(.title).foregroundStyle(Theme.graphite)
                    Text("No downloads yet").retro(12, .semibold)
                    Text("Paste a URL above and hit Queue Download.")
                        .retro(9, .light, color: Theme.graphite, tracking: 1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(30)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedJobs.enumerated()), id: \.element.id) { idx, job in
                        if idx > 0 {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }
                        jobRow(job)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func jobRow(_ job: AntraJob) -> some View {
        VStack(spacing: 0) {
            Button {
                if expandedJobs.contains(job.id) { expandedJobs.remove(job.id) }
                else { expandedJobs.insert(job.id) }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    statusIcon(job).frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.title ?? shortURL(job.url)).retro(12, .semibold).lineLimit(2)
                        Text(subtitleFor(job))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.graphite).lineLimit(1)
                        if !job.isTerminal, let pct = job.progress {
                            ProgressBar(percent: pct).frame(height: 3).padding(.top, 4)
                        }
                    }
                    Spacer(minLength: 4)
                    if !job.isTerminal, let pct = job.progress {
                        Text("\(pct)%")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    }
                    Image(systemName: expandedJobs.contains(job.id) ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(Theme.graphite)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedJobs.contains(job.id),
               let tracks = tracksByJob[job.id], !tracks.isEmpty {
                tracksList(tracks)
                    .padding(.top, 4).padding(.bottom, 8)
            } else if expandedJobs.contains(job.id) {
                Text("No per-track breakdown yet — single-track jobs won't have one.")
                    .retro(9, .light, color: Theme.graphite, tracking: 1)
                    .padding(.horizontal, 40).padding(.bottom, 10)
            }
        }
    }

    private func tracksList(_ tracks: [AntraTrack]) -> some View {
        VStack(spacing: 0) {
            ForEach(tracks) { t in
                HStack(spacing: 10) {
                    trackDot(t.state)
                    Text("\(t.index)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.graphite).frame(width: 26, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        if let a = t.artist, !a.isEmpty {
                            Text(a).font(.system(size: 10)).foregroundStyle(Theme.graphite).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(t.state.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(trackStateColor(t.state))
                }
                .padding(.leading, 40).padding(.trailing, 8).padding(.vertical, 5)
                .background(Theme.paper.opacity(0.5))
            }
        }
    }

    @ViewBuilder private func trackDot(_ state: String) -> some View {
        Circle()
            .fill(trackStateColor(state))
            .frame(width: 8, height: 8)
    }

    private func trackStateColor(_ state: String) -> Color {
        switch state {
        case "done":         return Theme.accent
        case "skipped":      return Theme.graphite
        case "downloading":  return .orange
        case "failed":       return .red
        default:             return Theme.hairline    // queued
        }
    }

    @ViewBuilder private func statusIcon(_ job: AntraJob) -> some View {
        switch job.status {
        case "done":            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Theme.accent)
        case "error", "failed": Image(systemName: "exclamationmark.circle.fill").font(.title3).foregroundStyle(.red)
        case "running":         ProgressView().controlSize(.small)
        default:                Image(systemName: "clock").font(.title3).foregroundStyle(Theme.graphite)
        }
    }

    private func subtitleFor(_ job: AntraJob) -> String {
        let parts: [String?] = [
            job.folder?.isEmpty == false ? "→ \(job.folder!)" : nil,
            job.format?.uppercased(),
            statusLabel(job),
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    private func statusLabel(_ job: AntraJob) -> String {
        switch job.status {
        case "done":            return "Complete"
        case "running":         return "Downloading"
        case "queued":          return "Queued"
        case "error", "failed": return "Failed"
        default:                return job.status.capitalized
        }
    }

    private func shortURL(_ url: String) -> String {
        guard let comps = URLComponents(string: url), let host = comps.host else { return url }
        return "\(host)\(comps.path)"
    }

    // MARK: - Actions

    private func queue() {
        guard canQueue, let client = session.client else { return }
        let url = urlText.trimmingCharacters(in: .whitespaces)
        queuing = true
        Task {
            do {
                _ = try await client.startAntraDownload(url: url, format: format, folder: folder)
                urlText = ""
                showToast(folder.map { "Queued → \($0)" } ?? "Queued to library root")
                await refreshJobs()
            } catch {
                showToast("Couldn't queue the download")
            }
            queuing = false
        }
    }

    // MARK: - Data

    private func loadFolders() async {
        guard folders.isEmpty, let client = session.client else { return }
        folders = (try? await client.libraryFolders()) ?? []
    }

    private func refreshJobs() async {
        guard let client = session.client else { return }
        do {
            let list = try await client.antraJobs()
            let running = list.filter { $0.status == "running" || $0.status == "queued" }

            // Auto-expand the newest running job so users see per-track state
            // without needing to tap.
            if let newestRunning = running.max(by: { $0.id < $1.id }) {
                expandedJobs.insert(newestRunning.id)
            }

            var withProgress = list
            if !running.isEmpty {
                await withTaskGroup(of: AntraJob?.self) { group in
                    for j in running {
                        group.addTask { try? await client.antraJobStatus(id: j.id) }
                    }
                    for await updated in group {
                        if let updated,
                           let idx = withProgress.firstIndex(where: { $0.id == updated.id }) {
                            withProgress[idx] = updated
                        }
                    }
                }
            }
            jobs = withProgress

            // Fetch per-track state for every currently-expanded job.
            let toFetch = expandedJobs.intersection(Set(withProgress.map(\.id)))
            await withTaskGroup(of: (Int, [AntraTrack]).self) { group in
                for id in toFetch {
                    group.addTask { (id, (try? await client.antraJobTracks(id: id)) ?? []) }
                }
                for await (id, tracks) in group {
                    tracksByJob[id] = tracks
                }
            }
        } catch { /* keep last-known */ }
        isLoading = false
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak session] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard session != nil else { return }
                await refreshJobs()
            }
        }
    }

    // MARK: - Toast

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast).retro(11, .medium, color: Theme.paper, tracking: 1)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Theme.ink, in: Capsule())
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}

// MARK: - Progress bar

private struct ProgressBar: View {
    let percent: Int
    var body: some View {
        GeometryReader { geo in
            let frac = CGFloat(max(0, min(100, percent))) / 100
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline)
                Capsule().fill(Theme.accent).frame(width: geo.size.width * frac)
            }
        }
    }
}
