//
//  ErrorView.swift
//  SwiftUIExample
//
//  Created by Иван Галкин on 08.05.2025.
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        Text("\(error)")
            .padding()
            .navigationTitle("Main Screen")
    }
}

private class SomeError: Error {}
#Preview {
    ErrorView(
        error: SomeError()
    )
}
