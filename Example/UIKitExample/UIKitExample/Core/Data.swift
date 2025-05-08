//
//  Dependency.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 07.05.2025.
//

import Foundation

protocol HttpService: AnyObject {
    func getCatFact() async throws -> CatFact
}

final class EntityService: HttpService {
    func getCatFact() async throws -> CatFact {
        let (data, _) = try await URLSession.shared.data(
            for: URLRequest(
                url: URL(
                    string: "https://catfact.ninja/fact"
                )!
            )
        )

        return try JSONDecoder().decode(CatFact.self, from: data)
    }
}

protocol Database: AnyObject {}
final class EntityDatabase: Database {}

protocol Repository: AnyObject {}
final class EntityRepository: Repository {}
