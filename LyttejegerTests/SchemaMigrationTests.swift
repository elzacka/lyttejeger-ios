import Foundation
import Testing
import SwiftData
@testable import Lyttejeger

/// Guards the retrofit of VersionedSchema onto a store that shipped without one.
/// Each test writes a store on disk the way v1.0.8 (build 14) did — a bare
/// `Schema([...])` with no migration plan — then reopens that same file with
/// `LyttejegerStore.makeContainer()` and checks the rows survived.
@Suite("SwiftData schema migration")
struct SchemaMigrationTests {

    /// The pre-versioning schema, exactly as build 14 constructed it.
    private static var legacySchema: Schema {
        Schema([QueueItem.self, Subscription.self, PlaybackPosition.self])
    }

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func removeStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let path = URL(fileURLWithPath: url.path + suffix)
            if fm.fileExists(atPath: path.path) {
                try? fm.removeItem(at: path)
            }
        }
    }

    @Test("data written by the unversioned schema survives reopening with V1")
    func legacyStoreOpensUnderV1() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        // 1. Write with the old, unversioned schema — no migration plan.
        do {
            let legacy = try ModelContainer(
                for: Self.legacySchema,
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(legacy)
            context.insert(Subscription(
                podcastId: "p1",
                title: "Abels tårn",
                author: "NRK",
                imageUrl: "https://example.com/a.jpg",
                feedUrl: "https://example.com/a.xml"
            ))
            context.insert(QueueItem(
                episodeId: "e1",
                podcastId: "p1",
                title: "Episode 1",
                podcastTitle: "Abels tårn",
                audioUrl: "https://example.com/e1.mp3",
                position: 3
            ))
            context.insert(PlaybackPosition(
                episodeId: "e1",
                position: 120,
                duration: 1800,
                completed: false
            ))
            try context.save()
        }

        // 2. Reopen the same file through the versioned schema + migration plan.
        let migrated = try ModelContainer(
            for: LyttejegerStore.schema,
            migrationPlan: LyttejegerMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(migrated)

        let subs = try context.fetch(FetchDescriptor<Subscription>())
        #expect(subs.count == 1)
        #expect(subs.first?.podcastId == "p1")
        #expect(subs.first?.title == "Abels tårn")
        #expect(subs.first?.feedUrl == "https://example.com/a.xml")

        let queue = try context.fetch(FetchDescriptor<QueueItem>())
        #expect(queue.count == 1)
        #expect(queue.first?.episodeId == "e1")
        #expect(queue.first?.audioUrl == "https://example.com/e1.mp3")
        #expect(queue.first?.position == 3)

        let positions = try context.fetch(FetchDescriptor<PlaybackPosition>())
        #expect(positions.count == 1)
        #expect(positions.first?.episodeId == "e1")
        #expect(positions.first?.position == 120)
        #expect(positions.first?.duration == 1800)
        #expect(positions.first?.completed == false)
    }

    @Test("the unique constraint still holds after migration")
    func uniqueConstraintSurvives() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        do {
            let legacy = try ModelContainer(
                for: Self.legacySchema,
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(legacy)
            context.insert(QueueItem(
                episodeId: "dup",
                podcastId: "p1",
                title: "First",
                podcastTitle: "Pod",
                audioUrl: "https://example.com/1.mp3"
            ))
            try context.save()
        }

        let migrated = try ModelContainer(
            for: LyttejegerStore.schema,
            migrationPlan: LyttejegerMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(migrated)

        // @Attribute(.unique) upserts rather than duplicating.
        context.insert(QueueItem(
            episodeId: "dup",
            podcastId: "p1",
            title: "Second",
            podcastTitle: "Pod",
            audioUrl: "https://example.com/2.mp3"
        ))
        try context.save()

        let items = try context.fetch(FetchDescriptor<QueueItem>())
        #expect(items.count == 1)
        #expect(items.first?.title == "Second")
    }

    @Test("V1 covers exactly the three shipped models")
    func v1ModelsAreComplete() {
        let names = Set(LyttejegerSchemaV1.models.map { String(describing: $0) })
        #expect(names == ["QueueItem", "Subscription", "PlaybackPosition"])
    }

    /// Deployed stores carry 1.0.0 in their metadata. Changing this strands them.
    @Test("V1 version identifier is frozen at 1.0.0")
    func v1VersionIsFrozen() {
        #expect(LyttejegerSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }
}
