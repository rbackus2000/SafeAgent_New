import Foundation
import MessageUI
import SwiftUI
import CoreLocation

class NotificationService: NSObject, ObservableObject, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate {
    static let shared = NotificationService()
    
    // MARK: - In-app SMS (user must confirm/send)
    func sendEmergencySMS(to phoneNumbers: [String], message: String, presentingViewController: UIViewController) {
        guard MFMessageComposeViewController.canSendText() else {
            print("SMS not supported on this device")
            return
        }
        let composeVC = MFMessageComposeViewController()
        composeVC.messageComposeDelegate = self
        composeVC.recipients = phoneNumbers
        composeVC.body = message
        presentingViewController.present(composeVC, animated: true)
    }
    
    // MARK: - In-app Email (user must confirm/send)
    func sendEmergencyEmail(to emails: [String], subject: String, body: String, presentingViewController: UIViewController) {
        guard MFMailComposeViewController.canSendMail() else {
            print("Mail not supported on this device")
            return
        }
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = self
        mailVC.setToRecipients(emails)
        mailVC.setSubject(subject)
        mailVC.setMessageBody(body, isHTML: false)
        presentingViewController.present(mailVC, animated: true)
    }
    
    // MARK: - MFMessageComposeViewControllerDelegate
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
    // MARK: - MFMailComposeViewControllerDelegate
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
    // MARK: - Remote Push/Third-Party Integration
    // Noonlight API integration for sending panic alerts
    func sendNoonlightPanicAlert(
        userId: String,
        location: CLLocationCoordinate2D,
        address: String,
        notes: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let token = "GZj1Bi0laouXqesiSRAhLd2uvQztdAV" // Replace with your secure storage/logic
        let url = URL(string: "https://api.noonlight.com/platform/v1/alarms")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "user_id": userId,
            "location": [
                "lat": location.latitude,
                "lng": location.longitude,
                "address": address
            ],
            "event": [
                "event_type": "panic",
                "notes": notes
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "No response")
                return
            }
            if httpResponse.statusCode == 201 {
                completion(true, nil)
            } else {
                let msg = String(data: data ?? Data(), encoding: .utf8)
                completion(false, "Failed: \(msg ?? "Unknown error")")
            }
        }
        task.resume()
    }

}
