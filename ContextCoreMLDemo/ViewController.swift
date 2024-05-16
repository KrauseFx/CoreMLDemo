import UIKit
import CoreML

class ViewController: UIViewController {
    let modelDownloadManager = ModelDownloadManager()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func runLatestLocalModel() {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        do {
            let modelInput = MyFirstCustomModelInput(input: [
               Double(batteryLevel),
               Double(batteryCharging ? 1.0 : 0.0)
            ])
            if let result = try modelDownloadManager.latestModel()?.prediction(input: modelInput) {
                let classProbabilities = result.featureValue(for: "classProbability")?.dictionaryValue
                let upsellProbability = classProbabilities?["Purchased"]?.doubleValue ?? -1
                
                showAlertDialog(message:("Chances of Upsell: \(upsellProbability)"))
            } else {
                showAlertDialog(message:("Could not run CoreML model"))
            }
        } catch {
            showAlertDialog(message:("Error running CoreML file: \(error)"))
        }
    }
    
    @IBAction func downloadLatestModel() {
        Task {
            do {
                try await modelDownloadManager.checkForModelUpdates()
                showAlertDialog(message:("Model update completed successfully."))
            } catch {
                // Handle possible errors here
                showAlertDialog(message:("Failed to update model: \(error.localizedDescription)"))
            }
        }
    }
    
    internal func showAlertDialog(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
