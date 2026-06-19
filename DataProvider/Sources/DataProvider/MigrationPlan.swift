//
//  MigrationPlan.swift
//  MyAnimeList
//
//  Created by Samuel He on 2025/5/10.
//

import Foundation
import SwiftData

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self,
            SchemaV2.self,
            SchemaV2_0_1.self,
            SchemaV2_1_0.self,
            SchemaV2_1_1.self,
            SchemaV2_2_0.self,
            SchemaV2_2_1.self,
            SchemaV2_3_0.self,
            SchemaV2_3_1.self,
            SchemaV2_3_2.self,
            SchemaV2_4_0.self,
            SchemaV2_4_1.self,
            SchemaV2_5_0.self,
            SchemaV2_6_0.self,
            SchemaV2_7_0.self,
            SchemaV2_7_1.self,
            SchemaV2_7_2.self,
            SchemaV2_7_3.self,
            SchemaV2_7_4.self,
            SchemaV2_7_5.self,
            SchemaV2_7_6.self,
            SchemaV2_7_7.self,
            SchemaV2_7_8.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV2_0_1.self),
            .migrateV201ToV210(),
            .lightweight(fromVersion: SchemaV2_1_0.self, toVersion: SchemaV2_1_1.self),
            .lightweight(fromVersion: SchemaV2_1_1.self, toVersion: SchemaV2_2_0.self),
            .lightweight(fromVersion: SchemaV2_2_0.self, toVersion: SchemaV2_2_1.self),
            .lightweight(fromVersion: SchemaV2_2_1.self, toVersion: SchemaV2_3_0.self),
            .lightweight(fromVersion: SchemaV2_3_0.self, toVersion: SchemaV2_3_1.self),
            .lightweight(fromVersion: SchemaV2_3_1.self, toVersion: SchemaV2_3_2.self),
            .lightweight(fromVersion: SchemaV2_3_2.self, toVersion: SchemaV2_4_0.self),
            .lightweight(fromVersion: SchemaV2_4_0.self, toVersion: SchemaV2_4_1.self),
            .lightweight(fromVersion: SchemaV2_4_1.self, toVersion: SchemaV2_5_0.self),
            .lightweight(fromVersion: SchemaV2_5_0.self, toVersion: SchemaV2_6_0.self),
            .migrateV260ToV270(),
            .migrateV270ToV271(),
            .lightweight(fromVersion: SchemaV2_7_1.self, toVersion: SchemaV2_7_2.self),
            .lightweight(fromVersion: SchemaV2_7_2.self, toVersion: SchemaV2_7_3.self),
            .migrateV273ToV274(),
            .lightweight(fromVersion: SchemaV2_7_4.self, toVersion: SchemaV2_7_5.self),
            .lightweight(fromVersion: SchemaV2_7_5.self, toVersion: SchemaV2_7_6.self),
            .lightweight(fromVersion: SchemaV2_7_6.self, toVersion: SchemaV2_7_7.self),
            .lightweight(fromVersion: SchemaV2_7_7.self, toVersion: SchemaV2_7_8.self)
        ]
    }
}

extension MigrationStage {
    private struct ParentSeriesCleanupPlan {
        let canonicalParentOldIDByTMDbID: [Int: PersistentIdentifier]
        let discardedParentOldIDs: Set<PersistentIdentifier>
    }

    // Small thread-safe mutable box used to share captured snapshot storage
    // between @Sendable migration closures. We provide explicit synchronized
    // accessors so mutation from concurrently executing code is safe.
    private final class SnapshotsBox: @unchecked Sendable {
        private var _value: [AnimeEntryMigrationDTO] = []
        private let lock = NSLock()

        func set(_ newValue: [AnimeEntryMigrationDTO]) {
            lock.lock()
            _value = newValue
            lock.unlock()
        }

        func get() -> [AnimeEntryMigrationDTO] {
            lock.lock()
            let v = _value
            lock.unlock()
            return v
        }
    }

    static func migrateV201ToV210() -> MigrationStage {
        let snapshotsBox = SnapshotsBox()

        return MigrationStage.custom(
            fromVersion: SchemaV2_0_1.self,
            toVersion: SchemaV2_1_0.self,
            willMigrate: { context in
                snapshotsBox.set(try Self.captureAndDeleteEntries(in: context) { (index: Int, entry: SchemaV2_0_1.AnimeEntry) in
                    // Map old entry to a migration DTO that can be recreated later.
                    let type: AnimeType
                    switch entry.entryType {
                    case .movie: type = .movie
                    case .tvSeries: type = .series
                    case .tvSeason(let seasonNumber, let parentSeriesID):
                        type = .season(seasonNumber: seasonNumber, parentSeriesID: parentSeriesID)
                    }

                    return AnimeEntryMigrationDTO(
                        originalIndex: index,
                        oldID: entry.persistentModelID,
                        parentSeriesOldID: nil,
                        name: entry.name,
                        nameTranslations: [:],
                        overview: entry.overview,
                        overviewTranslations: [:],
                        onAirDate: entry.onAirDate,
                        type: type,
                        linkToDetails: entry.linkToDetails,
                        posterURL: entry.posterURL,
                        backdropURL: entry.backdropURL,
                        tmdbID: entry.tmdbID,
                        detail: nil,
                        onDisplay: true,
                        watchStatus: .planToWatch,
                        dateSaved: entry.dateSaved,
                        dateStarted: entry.dateStarted,
                        dateFinished: entry.dateFinished,
                        score: nil,
                        favorite: false,
                        notes: "",
                        usingCustomPoster: entry.useSeriesPoster
                    )
                })
            },
            didMigrate: { context in
                try Self.rebuildEntries(
                    from: snapshotsBox.get(),
                    in: context,
                    makeEntry: { snapshot in
                        // Create the new SchemaV2_1_0.AnimeEntry from snapshot
                        let type: AnimeType
                        switch snapshot.type {
                        case .movie: type = .movie
                        case .series: type = .series
                        case .season(let seasonNumber, let parentSeriesID):
                            type = .season(seasonNumber: seasonNumber, parentSeriesID: parentSeriesID)
                        }

                        return SchemaV2_1_0.AnimeEntry(
                            name: snapshot.name,
                            overview: snapshot.overview,
                            onAirDate: snapshot.onAirDate,
                            type: type,
                            linkToDetails: snapshot.linkToDetails,
                            posterURL: snapshot.posterURL,
                            backdropURL: snapshot.backdropURL,
                            tmdbID: snapshot.tmdbID,
                            useSeriesPoster: snapshot.usingCustomPoster,
                            dateSaved: snapshot.dateSaved,
                            dateStarted: snapshot.dateStarted,
                            dateFinished: snapshot.dateFinished
                        )
                    },
                    // No parent relationships exist in this migration; provide a no-op setParent closure
                    setParent: { (_: SchemaV2_1_0.AnimeEntry, _: SchemaV2_1_0.AnimeEntry) in }
                )
            }
        )
    }

    static func migrateV260ToV270() -> MigrationStage {
        let snapshotsBox = SnapshotsBox()

        return MigrationStage.custom(
            fromVersion: SchemaV2_6_0.self,
            toVersion: SchemaV2_7_0.self,
            willMigrate: { context in
                snapshotsBox.set(try Self.captureAndDeleteEntries(in: context) {
                    (index: Int, entry: SchemaV2_6_0.AnimeEntry) in
                    entry.migrationDTO(index: index)
                })
            },
            didMigrate: { context in
                try Self.rebuildEntries(
                    from: snapshotsBox.get(),
                    in: context,
                    makeEntry: { snapshot in
                        SchemaV2_7_0.AnimeEntry(
                            migrationDTO: snapshot,
                            detail: snapshot.detail.map(SchemaV2_7_0.AnimeEntryDetail.init(from:)),
                            watchStatus: .init(snapshot.watchStatus)
                        )
                    },
                    setParent: { entry, parentEntry in
                        entry.parentSeriesEntry = parentEntry
                    }
                )
            }
        )
    }

    static func migrateV270ToV271() -> MigrationStage {
        let snapshotsBox = SnapshotsBox()

        return MigrationStage.custom(
            fromVersion: SchemaV2_7_0.self,
            toVersion: SchemaV2_7_1.self,
            willMigrate: { context in
                snapshotsBox.set(try Self.captureAndDeleteEntries(in: context) {
                    (index: Int, entry: SchemaV2_7_0.AnimeEntry) in
                    entry.migrationDTO(index: index)
                })
            },
            didMigrate: { context in
                try Self.rebuildEntries(
                    from: snapshotsBox.get(),
                    in: context,
                    makeEntry: { snapshot in
                        SchemaV2_7_1.AnimeEntry(
                            migrationDTO: snapshot,
                            detail: snapshot.detail.map(SchemaV2_7_1.AnimeEntryDetail.init(from:)),
                            watchStatus: .init(snapshot.watchStatus)
                        )
                    },
                    setParent: { entry, parentEntry in
                        entry.parentSeriesEntry = parentEntry
                    }
                )
            }
        )
    }

    static func migrateV273ToV274() -> MigrationStage {
        let snapshotsBox = SnapshotsBox()

        return MigrationStage.custom(
            fromVersion: SchemaV2_7_3.self,
            toVersion: SchemaV2_7_4.self,
            willMigrate: { context in
                snapshotsBox.set(try Self.captureAndDeleteEntries(in: context) {
                    (index: Int, entry: SchemaV2_7_3.AnimeEntry) in
                    entry.migrationDTO(index: index)
                })
            },
            didMigrate: { context in
                let snapshots = snapshotsBox.get()
                let cleanupPlan = Self.parentSeriesCleanupPlan(from: snapshots)
                try Self.rebuildEntries(
                    from: snapshots,
                    in: context,
                    include: { snapshot in
                        cleanupPlan.discardedParentOldIDs.contains(snapshot.oldID) == false
                    },
                    makeEntry: { snapshot in
                        SchemaV2_7_4.AnimeEntry(
                            migrationDTO: snapshot,
                            detail: snapshot.detail.map(SchemaV2_7_4.AnimeEntryDetail.init(from:)),
                            watchStatus: .init(snapshot.watchStatus)
                        )
                    },
                    setParent: { entry, parentEntry in
                        entry.parentSeriesEntry = parentEntry
                    },
                    resolveParentOldID: { snapshot in
                        Self.resolvedParentOldID(for: snapshot, cleanupPlan: cleanupPlan)
                    }
                )
            }
        )
    }

    private static func captureAndDeleteEntries<Entry: PersistentModel>(
        in context: ModelContext,
        map: (Int, Entry) -> AnimeEntryMigrationDTO
    ) throws -> [AnimeEntryMigrationDTO] {
        let oldEntries = try context.fetch(FetchDescriptor<Entry>())
        let snapshots = oldEntries.enumerated().map { index, entry in
            map(index, entry)
        }

        for entry in oldEntries {
            context.delete(entry)
        }
        try context.save()

        return snapshots
    }

    private static func rebuildEntries<Entry: PersistentModel>(
        from snapshots: [AnimeEntryMigrationDTO],
        in context: ModelContext,
        include: (AnimeEntryMigrationDTO) -> Bool = { _ in true },
        makeEntry: (AnimeEntryMigrationDTO) -> Entry,
        setParent: (Entry, Entry) -> Void,
        resolveParentOldID: (AnimeEntryMigrationDTO) -> PersistentIdentifier? = {
            $0.parentSeriesOldID
        }
    ) throws {
        var newEntriesByOldID: [PersistentIdentifier: Entry] = [:]

        for snapshot in snapshots where include(snapshot) {
            let entry = makeEntry(snapshot)
            context.insert(entry)
            newEntriesByOldID[snapshot.oldID] = entry
        }

        for snapshot in snapshots {
            guard
                let entry = newEntriesByOldID[snapshot.oldID],
                let parentOldID = resolveParentOldID(snapshot),
                let parentEntry = newEntriesByOldID[parentOldID]
            else {
                continue
            }
            setParent(entry, parentEntry)
        }

        try context.save()
    }

    private static func parentSeriesCleanupPlan(
        from snapshots: [AnimeEntryMigrationDTO]
    ) -> ParentSeriesCleanupPlan {
        let rootSeriesSnapshots = snapshots.filter(\.isRootSeriesEntry)
        let referencedChildCountByOldID = snapshots.reduce(into: [PersistentIdentifier: Int]()) {
            counts,
            snapshot in
            guard let parentSeriesOldID = snapshot.parentSeriesOldID else { return }
            counts[parentSeriesOldID, default: 0] += 1
        }
        let requiredSeasonCountByParentTMDbID = snapshots.reduce(into: [Int: Int]()) {
            counts,
            snapshot in
            guard let parentSeriesID = snapshot.parentSeriesID else { return }
            counts[parentSeriesID, default: 0] += 1
        }

        var canonicalParentOldIDByTMDbID: [Int: PersistentIdentifier] = [:]
        var discardedParentOldIDs = Set<PersistentIdentifier>()

        for (tmdbID, group) in Dictionary(grouping: rootSeriesSnapshots, by: \.tmdbID) {
            let visibleParents = group.filter(\.onDisplay)
            if let canonicalVisibleParent = bestParentSeriesSnapshot(
                from: visibleParents,
                referencedChildCountByOldID: referencedChildCountByOldID
            ) {
                canonicalParentOldIDByTMDbID[tmdbID] = canonicalVisibleParent.oldID
                discardedParentOldIDs.formUnion(
                    group
                        .filter { $0.onDisplay == false }
                        .map(\.oldID)
                )
                continue
            }

            guard
                requiredSeasonCountByParentTMDbID[tmdbID, default: 0] > 0,
                let canonicalHiddenParent = bestParentSeriesSnapshot(
                    from: group,
                    referencedChildCountByOldID: referencedChildCountByOldID
                )
            else {
                discardedParentOldIDs.formUnion(group.map(\.oldID))
                continue
            }

            canonicalParentOldIDByTMDbID[tmdbID] = canonicalHiddenParent.oldID
            discardedParentOldIDs.formUnion(
                group
                    .filter { $0.oldID != canonicalHiddenParent.oldID }
                    .map(\.oldID)
            )
        }

        return ParentSeriesCleanupPlan(
            canonicalParentOldIDByTMDbID: canonicalParentOldIDByTMDbID,
            discardedParentOldIDs: discardedParentOldIDs
        )
    }

    private static func bestParentSeriesSnapshot(
        from candidates: [AnimeEntryMigrationDTO],
        referencedChildCountByOldID: [PersistentIdentifier: Int]
    ) -> AnimeEntryMigrationDTO? {
        candidates.sorted { lhs, rhs in
            if lhs.onDisplay != rhs.onDisplay {
                return lhs.onDisplay && !rhs.onDisplay
            }

            let lhsReferencedChildCount = referencedChildCountByOldID[lhs.oldID, default: 0]
            let rhsReferencedChildCount = referencedChildCountByOldID[rhs.oldID, default: 0]
            if lhsReferencedChildCount != rhsReferencedChildCount {
                return lhsReferencedChildCount > rhsReferencedChildCount
            }

            if lhs.hasDetail != rhs.hasDetail {
                return lhs.hasDetail && !rhs.hasDetail
            }

            if lhs.usingCustomPoster != rhs.usingCustomPoster {
                return lhs.usingCustomPoster && !rhs.usingCustomPoster
            }

            if lhs.dateSaved != rhs.dateSaved {
                return lhs.dateSaved > rhs.dateSaved
            }

            return lhs.originalIndex < rhs.originalIndex
        }.first
    }

    private static func resolvedParentOldID(
        for snapshot: AnimeEntryMigrationDTO,
        cleanupPlan: ParentSeriesCleanupPlan
    ) -> PersistentIdentifier? {
        guard let parentSeriesID = snapshot.parentSeriesID else {
            return snapshot.parentSeriesOldID
        }

        if let canonicalParentOldID = cleanupPlan.canonicalParentOldIDByTMDbID[parentSeriesID] {
            return canonicalParentOldID
        }

        guard let parentSeriesOldID = snapshot.parentSeriesOldID else { return nil }
        guard cleanupPlan.discardedParentOldIDs.contains(parentSeriesOldID) == false else {
            return nil
        }
        return parentSeriesOldID
    }
}
