//
//  GradientBackground.swift
//  WarrantyVault
//
//  Pure black background. No gradient — the type name is kept so callsites
//  don't need to change. `SolidBackground` is the preferred name in new code.
//

import SwiftUI

struct GradientBackground: View {
    var body: some View {
        AppColors.bgApp
            .ignoresSafeArea()
    }
}

typealias SolidBackground = GradientBackground

#Preview {
    GradientBackground()
}
