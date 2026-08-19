import Foundation
import SwiftData

/// V1 is the schema shipped in v1.0.8 (build 14): QueueItem, Subscription and
/// PlaybackPosition exactly as they were deployed. The models stay at file scope
/// rather than nested inside this enum so their entity identity in existing
/// stores is unchanged.
///
/// `versionIdentifier` is written into every user's store metadata the first time
/// they launch a build that carries it. Never change it retroactively — bump to a
/// new VersionedSchema instead and add a MigrationStage.
enum LyttejegerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [QueueItem.self, Subscription.self, PlaybackPosition.self]
    }
}

enum LyttejegerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LyttejegerSchemaV1.self] }

    /// Empty until a V2 exists. Each future version adds one stage here.
    static var stages: [MigrationStage] { [] }
}

/// Single definition of the app's store, so the main app and the background
/// refresh task cannot drift apart on schema or migration plan.
enum LyttejegerStore {
    static let schema = Schema(versionedSchema: LyttejegerSchemaV1.self)

    static func makeContainer() throws -> ModelContainer {
        // SwiftData's default store lives in Application Support, which does
        // not exist in a fresh app container. CoreData does recover by creating
        // it, but only after logging several hundred lines of stat failures at
        // error level on every first launch. Creating it up front keeps the
        // first launch quiet; CoreData's own recovery stays as the fallback if
        // this fails, so the error is deliberately not propagated.
        _ = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try ModelContainer(for: schema, migrationPlan: LyttejegerMigrationPlan.self)
    }
}
