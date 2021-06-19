//
//  ViewController.swift
//  AutoComplete
//
//  Created by Konstantinos Apostolakis on 19/6/21.
//

import UIKit
import SearchTextField

class ViewController: UIViewController {
    
    let endpoint = "https://xegr-geography.herokuapp.com/places/autocomplete"

    @IBOutlet weak var detailsStackView: UIStackView!
    
    @IBOutlet weak var titleTextField: SearchTextField!
    @IBOutlet weak var locationTextField: SearchTextField!
    @IBOutlet weak var priceTextField: SearchTextField!
    @IBOutlet weak var descriptionTextField: SearchTextField!
    
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    private var placesMap = [String: [String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDisappearing()
        setupTextFields()
    }
    
    private func setupUI() {
        submitButton.layer.cornerRadius = 8
        clearButton.layer.cornerRadius = 8
    }
    
    private func presentAlert(withTitle title: String, withMessage message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Keyboard functions
    
    private func setupKeyboardDisappearing() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - TextField functions
    
    private func setupTextFields() {
        titleTextField.delegate = self
        locationTextField.delegate = self
        priceTextField.delegate = self
        descriptionTextField.delegate = self
        
        locationTextField.addTarget(self, action: #selector(textFieldDidChange), for:.editingChanged)
    }
    
    @objc func textFieldDidChange() {
        let locationText = locationTextField.text ?? ""
        if locationText.count >= 3 {
            if let suggestionsFromMap = placesMap[locationText] {
                showAutoCompleteList(suggestions: suggestionsFromMap)
            } else {
                callAutocompleteAPI(withParameterText: locationText)
            }
        }
     }
    
    private func clearAllTextFields() {
        titleTextField.text = ""
        locationTextField.text = ""
        priceTextField.text = ""
        descriptionTextField.text = ""
    }
    
    private func showAutoCompleteList(suggestions: [String]) {
        locationTextField.filterStrings(suggestions)
        
        locationTextField.itemSelectionHandler = { filteredResults, itemPosition in
            let item = filteredResults[itemPosition]
            self.locationTextField.text = item.title
        }
    }
    
    // MARK: - Button action functions
    
    @IBAction func submitButtonTapped(_ sender: Any) {
        if inputsAreOK() {
            let jsonString = createJsonStringFromInputs()
            presentAlert(withTitle: "Inputs", withMessage: jsonString)
            clearAllTextFields()
        }
    }
    
    private func inputsAreOK() -> Bool {
        let title = titleTextField.text ?? ""
        if title.isEmpty {
            presentAlert(withTitle: "Title required", withMessage: "You cannot submit the ad. You must provide a title.")
            return false
        }
        
        let location = locationTextField.text ?? ""
        if !locationExistsInMap(locationText: location) {
            presentAlert(withTitle: "Valid location required", withMessage: "You cannot submit the ad. You must provide a location provided from the suggestions.")
            return false
        }

        return true
    }
    
    private func locationExistsInMap(locationText: String) -> Bool {
        for mapElement in placesMap {
            if mapElement.value.first(where: { $0 == locationText }) != nil {
                return true
            }
        }
        return false
    }
    
    private func createJsonStringFromInputs() -> String {
        let title = titleTextField.text ?? ""
        let location = locationTextField.text ?? ""
        let price = priceTextField.text ?? ""
        let description = descriptionTextField.text ?? ""
        
        let jsonString = "{\"title\": \"\(title)\", \"location\": \"\(location)\", \"price\": \"\(price)\", \"description\": \"\(description)\"}"
        return (jsonString.data(using: .utf8)?.prettyPrintedJSONString ?? "") as String
    }
    
    @IBAction func clearButtonTapped(_ sender: Any) {
        clearAllTextFields()
    }
    
    // MARK: - Rest API Call functions
    
    private func callAutocompleteAPI(withParameterText parameterText: String) {
        let endPointWithParameter = "\(endpoint)?input=\(parameterText)"
        guard let url = URL(string: endPointWithParameter) else {
            return
        }

        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            if error != nil {
                
            } else if let data = data {
                let suggestions = self.transformDataToSuggestions(data: data)
                self.showAutoCompleteList(suggestions: suggestions)
                
                self.placesMap[parameterText] = suggestions
                
                print(String(data: data, encoding: .utf8)!)
            }
        }

        task.resume()
    }
    
    private func transformDataToSuggestions(data: Data) -> [String] {
        var suggestionTexts = [String]()
        let placesData = try! JSONDecoder().decode([Place].self, from: data)
        
        for place in placesData {
            if let suggestion = place.mainText {
                suggestionTexts.append(suggestion)
            }
        }
        return suggestionTexts
    }
    
}

// MARK: - Extensions

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dismissKeyboard()
        return true
    }
}

extension Data {
    var prettyPrintedJSONString: NSString? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }
        
        return prettyPrintedString
    }
}

// MARK: - Models

class Place: Decodable {
    var placeId: String?
    var mainText: String?
    var secondaryText: String?
    
    init(placeId: String?, mainText: String?, secondaryText: String?) {
        self.placeId = placeId
        self.mainText = mainText
        self.secondaryText = secondaryText
    }
}
