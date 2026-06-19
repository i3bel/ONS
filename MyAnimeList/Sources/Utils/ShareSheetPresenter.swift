//
//  ShareSheetPresenter.swift
//  MyAnimeList
//
//  Created by OpenAI Codex on behalf of Samuel He on 2026/5/9.
//

import SwiftUI
import UIKit

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any]) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Locate a valid root view controller early so we can attach popovers to a view
        let rootViewController = UIApplication.shared.connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }?
            .rootViewController
        guard let rootViewController else { return }

        // On iPad, attach the popover to an existing view in the view hierarchy instead of
        // creating a detached UIHostingController and using its view. Using a detached
        // hostingController.view can cause UIKit/SwiftUI view-hierarchy warnings.
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityViewController.popoverPresentationController?.sourceView = rootViewController.view
            activityViewController.popoverPresentationController?.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 1,
                height: 1
            )
        }

        if let presentedViewController = rootViewController.presentedViewController {
            presentedViewController.dismiss(
                animated: true,
                completion: {
                    rootViewController.present(activityViewController, animated: true)
                }
            )
        } else {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}
