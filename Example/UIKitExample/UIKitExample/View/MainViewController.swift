//
//  MainViewController.swift
//  UIKitExample
//
//  Created by Иван Галкин on 06.05.2025.
//

import UIKit

class MainViewController: UIViewController {
    // MARK: - Initialization
    
    init(
        initialCatFact: CatFact
    ) {
        self.initialCatFact = initialCatFact
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private properies
    
    private let initialCatFact: CatFact
    
    private let label: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Main Screen"
        self.view.backgroundColor = .systemBackground
        
        self.label.text = self.initialCatFact.fact
        self.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
}

