//  CoreDataManager.swift
//  CoreData stack for challenge S5.
//  VULN: SecretEntity stored in unencrypted SQLite — no NSPersistentStoreDescription encryption.
//
//  Model is built in code — no .xcdatamodeld file required.

import Foundation
import CoreData

final class CoreDataManager {

    static let shared = CoreDataManager()

    // MARK: - Programmatic model (replaces .xcdatamodeld)

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── SecretEntity ──
        let secret = NSEntityDescription()
        secret.name = "SecretEntity"
        secret.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let flagValue = NSAttributeDescription()
        flagValue.name = "flagValue"
        flagValue.attributeType = .stringAttributeType
        flagValue.isOptional = true

        let profileId = NSAttributeDescription()
        profileId.name = "profileId"
        profileId.attributeType = .stringAttributeType
        profileId.isOptional = true

        let roleName = NSAttributeDescription()
        roleName.name = "roleName"
        roleName.attributeType = .stringAttributeType
        roleName.isOptional = true

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = true

        secret.properties = [flagValue, profileId, roleName, createdAt]

        // ── AppEvent (decoy) ──
        let event = NSEntityDescription()
        event.name = "AppEvent"
        event.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let eventType = NSAttributeDescription()
        eventType.name = "eventType"
        eventType.attributeType = .stringAttributeType
        eventType.isOptional = true

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .stringAttributeType
        payload.isOptional = true

        let timestamp = NSAttributeDescription()
        timestamp.name = "timestamp"
        timestamp.attributeType = .dateAttributeType
        timestamp.isOptional = true

        event.properties = [eventType, payload, timestamp]

        model.entities = [secret, event]
        return model
    }

    // MARK: - Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CTFDataModel", managedObjectModel: CoreDataManager.buildModel())
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("[CTF] CoreData load error: \(error)")
            }
            // VULN: No encryption option set on storeDescription
            print("[CTF] CoreData store at: \(storeDescription.url?.path ?? "unknown")")
        }
        return container
    }()

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init() {}

    // MARK: - S5: Plant flag in SecretEntity

    func plantS5Flag() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "SecretEntity")
        request.predicate = NSPredicate(format: "flagValue != nil")
        let existing = (try? context.fetch(request))?.count ?? 0
        guard existing == 0 else { return }

        // VULN: Creating an entity with a sensitive value in unencrypted CoreData
        // On jailbroken device: sqlite3 <store>.sqlite 'SELECT ZFLAGVALUE FROM ZSECRETENTITY;'
        let entity = NSEntityDescription.insertNewObject(
            forEntityName: "SecretEntity",
            into: context
        )

        entity.setValue("IOSCTF{S5_coredata_persists_your_sins}", forKey: "flagValue")
        entity.setValue("ctf_profile_001", forKey: "profileId")
        entity.setValue("Administrator", forKey: "roleName")
        entity.setValue(Date(), forKey: "createdAt")

        try? context.save()
        print("[CTF] S5: CoreData SecretEntity planted")
    }
}
