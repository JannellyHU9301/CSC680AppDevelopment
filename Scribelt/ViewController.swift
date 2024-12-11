import UIKit
import Speech
import AVFoundation

class ViewController: UIViewController {

    // MARK: - UI Outlets
    @IBOutlet weak var speechLabel: UITextView!
    @IBOutlet weak var startButton: UIButton!
    
    // MARK: - Properties
    var audioEngine = AVAudioEngine()
    var speechRecognizer: SFSpeechRecognizer?
    var request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        requestSpeechAuthorization()
        
        startButton.addTarget(self, action: #selector(startButtonTapped(_:)), for: .touchUpInside)
        startButton.isEnabled = false
        
        // Configure TextView Appearance
        setupSpeechLabelAppearance()
        
        // Add Bar Buttons
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportText))
        let increaseTextSizeButton = UIBarButtonItem(image: UIImage(systemName: "textformat.size.larger"), style: .plain, target: self, action: #selector(increaseTextSize))
        let decreaseTextSizeButton = UIBarButtonItem(image: UIImage(systemName: "textformat.size.smaller"), style: .plain, target: self, action: #selector(decreaseTextSize))
        
        navigationItem.rightBarButtonItems = [exportButton, increaseTextSizeButton, decreaseTextSizeButton]
    }
    
    // MARK: - Setup Navigation Bar
    func setupNavigationBar() {
        title = "Scribelt"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
    
    // MARK: - Configure Speech Label Appearance
    func setupSpeechLabelAppearance() {
        speechLabel.layer.borderColor = UIColor.systemGray4.cgColor
        speechLabel.layer.borderWidth = 2.0
        speechLabel.layer.cornerRadius = 8.0
        speechLabel.layer.masksToBounds = true
    }
    
    // MARK: - Request Speech Authorization
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startButton.isEnabled = true
                case .denied:
                    self.speechLabel.text = "Speech recognition access denied."
                case .restricted:
                    self.speechLabel.text = "Speech recognition restricted on this device."
                case .notDetermined:
                    self.speechLabel.text = "Speech recognition not determined."
                @unknown default:
                    self.speechLabel.text = "An unknown error occurred."
                }
            }
        }
    }
    
    // MARK: - Start Button Action
    @objc func startButtonTapped(_ sender: UIButton) {
        if audioEngine.isRunning {
            stopRecording()
            startButton.setTitle("Start", for: .normal)
        } else {
            startRecording()
            startButton.setTitle("Stop", for: .normal)
        }
    }
    
    // MARK: - Start Recording
    func startRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            
            guard let recognizer = SFSpeechRecognizer() else {
                speechLabel.text = "Speech recognizer not available."
                return
            }
            
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.speechLabel.text = transcribedText
                    }
                }
                if error != nil {
                    self.stopRecording()
                }
            }
            
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
                self.request.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            speechLabel.text = "Listening..."
        } catch {
            speechLabel.text = "Audio engine could not start."
        }
    }
    
    // MARK: - Stop Recording
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.finish()
        recognitionTask = nil
        request.endAudio()
    }
    
    // MARK: - Export Text
    @objc func exportText() {
        guard let text = speechLabel.text, !text.isEmpty else {
            let alert = UIAlertController(title: "Error",
                                          message: "No text to export.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let fileName = "SpeechTranscription.txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            present(activityVC, animated: true)
        } catch {
            let alert = UIAlertController(title: "Export Failed",
                                          message: "Could not create the file.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    // MARK: - Adjust Text Size
    @objc func increaseTextSize() {
        adjustTextSize(by: 2)
    }

    @objc func decreaseTextSize() {
        adjustTextSize(by: -2)
    }

    func adjustTextSize(by increment: CGFloat) {
        let currentSize = speechLabel.font?.pointSize ?? 17
        let newSize = max(currentSize + increment, 12) // Minimum size of 12
        speechLabel.font = UIFont.systemFont(ofSize: newSize)
    }
}
