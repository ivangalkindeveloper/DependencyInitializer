//
//  ContentView.swift
//  SwiftUIExample
//
//  Created by Иван Галкин on 06.05.2025.
//

import SwiftUI

struct MainView: View {
    let initialCatFact: CatFact

    var body: some View {
        Text(initialCatFact.fact)
            .padding()
            .navigationTitle("Main Screen")
    }
}

#Preview {
    MainView(
        initialCatFact: CatFact(
            fact: "Cat Fact",
            length: 0
        )
    )
}
