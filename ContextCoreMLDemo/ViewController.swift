import UIKit
import CoreML

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        do {
            let modelInput = MyFirstCustomModelInput(input: [
               Double(batteryLevel),
               Double(batteryCharging ? 1.0 : 0.0)
            ])
            let result = try MyFirstCustomModel(configuration: MLModelConfiguration()).prediction(input: modelInput)
            let classProbabilities = result.featureValue(for: "classProbability")?.dictionaryValue
            let upsellProbability = classProbabilities?["Purchased"]?.doubleValue ?? -1

            print("Chances of Upsell: \(upsellProbability)")
        } catch {
            print("Error running CoreML file: \(error)")
        }
    }
}

