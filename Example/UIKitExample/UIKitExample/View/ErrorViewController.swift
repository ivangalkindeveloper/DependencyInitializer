//
//  ErrorViewController.swift
//  UIKitExample
//
//  Created by Иван Галкин on 07.05.2025.
//

import UIKit

class ErrorViewController: UIViewController {
    // MARK: - Initialization
    
    init(
        error: Error
    ) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private properies
    
    private let error: Error
    
    private let label: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Error Screen"
        self.view.backgroundColor = .red
        
        self.label.text = "\(error)"
        self.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
