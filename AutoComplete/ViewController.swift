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
        // Add gesture to dissapear the keyboard when the user taps outside of it
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
        
        // This is for the customization of autocomplete suggestions menu
        locationTextField.theme.font = UIFont.systemFont(ofSize: 16)
        locationTextField.theme.bgColor = UIColor.darkGray
        locationTextField.theme.fontColor = UIColor.white
        locationTextField.theme.separatorColor = UIColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
        locationTextField.theme.cellHeight = 50
    }
    
    @objc func textFieldDidChange() {
        let locationText = locationTextField.text ?? ""
        if locationText.count >= 3 {
            // If we have already searched for this keyword, do not search again. Just get it from the map
            if let suggestionsFromMap = placesMap[locationText] {
                showAutoCompleteList(suggestions: suggestionsFromMap)
            } else {
                callAutocompleteAPI(withParameterText: locationText)
            }
        } else {
            // If we have less than 3 letters, clear the suggestions to not show them
            locationTextField.filterStrings([])
        }
     }
    
    private func clearAllTextFields() {
        titleTextField.text = ""
        locationTextField.text = ""
        priceTextField.text = ""
        descriptionTextField.text = ""
    }
    
    private func showAutoCompleteList(suggestions: [String]) {
        // Run to main thread due to bug appeared
        DispatchQueue.main.async {
            self.locationTextField.filterStrings(suggestions)
            
            self.locationTextField.itemSelectionHandler = { filteredResults, itemPosition in
                let item = filteredResults[itemPosition]
                self.locationTextField.text = item.title
            }
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
        // Search in all elements of the map and if it exists in an array, return true
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
            // We do not need to handle the error. Just do not show anything
            if let data = data, error == nil {
                self.handleSuccess(parameterText: parameterText, data: data)
            }
        }

        task.resume()
    }
    
    private func handleSuccess(parameterText: String, data: Data) {
        let suggestions = self.transformDataToSuggestions(data: data)
        self.showAutoCompleteList(suggestions: suggestions)
        
        // Save the results to a map for not calling the API again with the same words
        self.placesMap[parameterText] = suggestions
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
        // Add action to dissapear the keyboard when the user taps to "Done" button of it
        dismissKeyboard()
        return true
    }
}

extension Data {
    // Use this function (yes, from google search!) to beautify the json we show on screen.
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
