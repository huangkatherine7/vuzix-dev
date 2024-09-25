//  ViewController.swift
//  SampleApp
//
//  The single biggest pitfall is forgetting to call commit().
//
//  Created by Vuzix on 9/19/23.
//



import UIKit
import UltraliteSDK
import Speech

// Sample app that shows some basic drawing on the Vuzix Z100 Smart Glasses.
// Extends UltraliteBaseViewController, which makes it much easier to call simple things, like taking an Ultralite control, taps, on application leaving, disconnections, etc.  You dont have to extend UltraliteBaseViewController, it is just a quick and easy way to listen for all the callbacks.  Everything in UltraliteBaseViewController, can be done with the SDK directly.  
class ViewController: UltraliteBaseViewController {
    //speech
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var speechInput: String = ""
    private var silenceTimer: Timer? //for detecting 3 seconds of silence (command ends)
    

    // Handles to the text objects we create. Save reference handles to move, update, remove.
    private var textHandle: Int?
    private var tapTextHandle: Int?
    
    private var autoScroller: ScrollLayout.AutoScroller?
    
    private var currentLayout: Ultralite.Layout?
    
    public var allQueries: String = ""
    public var finishedQuery : Bool = false
    
    public var currentSpeechInput: String = ""
    public var currentSpeechInputLen: Int = 0
    public var trimmedInput: String = ""
    public var noiseRemovedInput: String = ""
    

    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // timeout of the glasses display
        displayTimeout = 60
        // allow 1 tap
        maximumNumTaps = 1
        
        
        // Request authorization for speech recognition
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            default:
                print("Speech recognition not authorized")
            }
        }
        
        // Request notification permission for timer alerts
        //TODO: do I want more notifications for timer end
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }

    }
    
    override func onAppLeave() {
        stopControl()
    }
    
    @IBAction func showPicker() {
        showPairingPicker()
    }
    
    // Take control of the glasses.  Remember there could be another 3rd party app currently controlling the glasses.  The app in the foreground can take control away from someone else.
    func startControl(device: Ultralite, layout: Ultralite.Layout) -> Bool {
        //UltraliteManager.shared.currentDevice?.setLayout(layout: .canvas, timeout: displayTimeout)
        // OR convience method startControl() on UltraliteBaseViewContoller
        
        if currentLayout != layout {
            currentLayout = layout
            return device.requestControl(layout: layout, timeout: displayTimeout, hideStatusBar: true)
        }
        
        return true
    }
    
    // Start speech recognition and display the result on the glasses
    @IBAction func startSpeechRecognition(sender: Any) {
        // Cancel any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        speechInput = "" // Reset speech input

        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                self.speechInput = spokenText
                
                    
                self.resetSilenceTimer()
                
                self.speechInput = ""
                print("xxx SPEECH INPUT: \(self.speechInput)")
                
            } else if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                self.audioEngine.stop()
                node.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }
    
    
    private func resetSilenceTimer() {
        // Invalidate any existing timer
        silenceTimer?.invalidate()
        
        
        let currentInput = self.speechInput.trimmingCharacters(in: .whitespacesAndNewlines)


        // Start a new timer for 3 seconds
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            
            // Call handleTimerCommand when the timer expires!!!
            
            // Check if there's any speech input before processing
            guard let self = self else { return }
            if currentInput.isEmpty {
                return // No input, don't do anything
            }
            
            print("CURRENT LEN: \(currentSpeechInputLen)")
            print("CURRENT INPUT: \(currentInput)")
            
            //trim prior queries from the input
            trimmedInput = String(currentInput.dropFirst(currentSpeechInputLen)) //+1 to trim an accumulating space??
            print("TRIMMED INPUT: \(trimmedInput)")
            
        
            
            
            //check for key word
            if !trimmedInput.lowercased().contains("sapphire") {
                print("Returning because the key word wasn't found")
                self.currentSpeechInputLen = currentInput.count
                return
            }
            print("KEY WORD DETECTED!")
            
            
            //key word found, can proceed. Trim garbage noise from BEFORE the keyword
            //TODO: if statement to check for keyword is not needed since will return above if no keyword
            if let range = trimmedInput.lowercased().range(of: "sapphire") {
                trimmedInput = trimmedInput[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                print("TRIMMED INPUT:  \(trimmedInput)")
                print("ENTERED IF STATEMENT")
            }

            
            //perform queries
            print("TRIMMED INPUT OUTSIDE IF:  \(trimmedInput)")
//            trimmedInput = String(trimmedInput.dropFirst(9)) //trim 9 more to remove "sapphire" key word
            let commandType = self.router(trimmedInput)
            
            if commandType == "t" {
                self.handleTimerCommand(trimmedInput) // It's a timer command
   
            } else if commandType == "g" {
                self.handleLLMQuery(trimmedInput) // It's a general query
            }
            
            self.speechInput = "" // Clear input after processing
            self.currentSpeechInputLen = currentInput.count
        }
    }
    
    
    private func router(_ command: String) -> String? {
        let apiUrl = "https://integrate.api.nvidia.com/v1/chat/completions"
        let apiKey = "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"
        
        let userQuery = "Based on the following user query, return 'g' if it is a general question, and 't' if it is a request to set a timer. For example, command is 'set a 10 minute timer'. You will return JUST THE CHARACTER 't'. DO NOT RETURN ANYTHING ELSE. User query: \(command)"

        
        let requestBody: [String: Any] = [
            "model": "meta/llama-3.1-8b-instruct",
            "messages": [["role": "user", "content": userQuery]],
            "temperature": 0.2,
            "top_p": 0.7,
            "max_tokens": 1024
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return nil
        }
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        var finalAnswer: String = ""
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }

            guard let data = data else {
                semaphore.signal()
                return
            }

            finalAnswer = self.parseJSONResponse(data: data) ?? ""

            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait() // Wait for the request to complete
        
        print("\n\n")
        print("Final Answer: \(finalAnswer)")
        
        return finalAnswer
    }
    
    
    
    private func handleLLMQuery(_ userQuery: String) {
        let apiUrl = "https://integrate.api.nvidia.com/v1/chat/completions"
        let apiKey = "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"
        
        
        let requestBody: [String: Any] = [
            "model": "meta/llama-3.1-8b-instruct",
            "messages": [["role": "user", "content": userQuery]],
            "temperature": 0.2,
            "top_p": 0.7,
            "max_tokens": 1024
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return
        }
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        var finalAnswer: String = ""
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }

            guard let data = data else {
                semaphore.signal()
                return
            }

            finalAnswer = self.parseJSONResponse(data: data) ?? ""

            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait() // Wait for the request to complete
        
        print("\n\n")
        print("Final Answer: \(finalAnswer)")
        
        displayTextOnGlasses("\(finalAnswer)")
        
    }
    
    
    
    private func handleTimerCommand(_ command: String) {
        print("Command: \(command)")
        let timerDuration = parseTimerCommand(command)
        
        print("Timer Duration: \(timerDuration)")
        
        if let duration = timerDuration {
            setTimer(minutes: duration)
            displayTextOnGlasses("Timer set for \(duration) minutes!")
        } else {
            displayTextOnGlasses("Timer command not recognized.")
        }
    }
    
    private func parseTimerCommand(_ command: String) -> Int? {
        let apiUrl = "https://integrate.api.nvidia.com/v1/chat/completions"
        let apiKey = "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"
        
        let userQuery = "Based on the following user query, extract only the time as a number. For example, command is 'set a 10 minute timer'. You will return JUST THE NUMBER. DO NOT RETURN ANYTHING ELSE. User query: \(command)"

        
        let requestBody: [String: Any] = [
            "model": "meta/llama-3.1-8b-instruct",
            "messages": [["role": "user", "content": userQuery]],
            "temperature": 0.2,
            "top_p": 0.7,
            "max_tokens": 1024
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return nil
        }
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        var finalAnswer: String = ""
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                semaphore.signal()
                return
            }

            guard let data = data else {
                semaphore.signal()
                return
            }

            finalAnswer = self.parseJSONResponse(data: data) ?? ""

            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait() // Wait for the request to complete
        
        print("\n\n")
        print("Final Answer: \(finalAnswer)")

        
        // Convert finalAnswer to Int
        if let number = Int(finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)) {
            print("returning number")
            return number
        }
        return nil
    }
    
    private func parseJSONResponse(data: Data) -> String? {
        do {
            // Parse the JSON data
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // Access the "choices" array
                if let choices = json["choices"] as? [[String: Any]], let firstChoice = choices.first {
                    // Access the "message"
                    if let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] {
                        // Check if content is a string
                        if let contentString = content as? String {
                            return contentString // Return the content directly
                        } else {
                            print("Content is not a string.")
                        }
                    } else {
                        print("Failed to find message in choices.")
                    }
                } else {
                    print("No choices found in the response.")
                }
            }
        } catch {
            print("Failed to parse JSON: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func setTimer(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Finished"
        content.body = "Your \(minutes) minute timer is up!"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error setting timer notification: \(error.localizedDescription)")
            }
        }
        
        startCountdown(minutes: minutes)
    }
    
    private func startCountdown(minutes: Int) {
        var remainingTime = minutes * 60 // in seconds

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if remainingTime > 0 {
                remainingTime -= 1
                let minutesLeft = remainingTime / 60
                let secondsLeft = remainingTime % 60
                self.displayTextOnGlasses("Time left: \(minutesLeft):\(String(format: "%02d", secondsLeft))")
            } else {
                timer.invalidate()
                self.displayTextOnGlasses("Time's up!")
            }
        }
    }

    
    private func displayTextOnGlasses(_ text: String) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }

        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }

        if let textHandle = textHandle {
            _ = device.canvas.removeText(id: textHandle)
        }

        self.textHandle = device.canvas.createText(text: text, textAlignment: .center, textColor: .white, anchor: .center, xOffset: 0, yOffset: 0)
        device.canvas.commit()
    }

    
    // creates a text object with the text "Hello World" at dead center of display
    @IBAction func createHelloWorld(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        if let textHandle = textHandle {
           _ = device.canvas.removeText(id: textHandle)
        }
        
        self.textHandle = device.canvas.createText(text: "Hello World MEOW", textAlignment: .center, textColor: .white, anchor: .center, xOffset: 0, yOffset: 0)
        device.canvas.commit()


    }
    
    
    
    // move created text object to a random point
    @IBAction func moveHelloWorld(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice, let textHandle = textHandle else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        
        let random = randomPoint()
        _ = device.canvas.moveText(id: textHandle, x: Int(random.x), y: Int(random.y), duration: 1000)
        device.canvas.commit()
    }
    
    // removes created text object
    @IBAction func removeHelloWorld(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice, let textHandle = textHandle else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        if device.canvas.removeText(id: textHandle) {
            self.textHandle = nil
        }
        device.canvas.commit()
    }
    
    // creates an animation in bottom right corner.  Three frames is the max.  Duration of the animation is 3 seconds.
    @IBAction func createAnimation(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }

        guard let image1 = UIImage(named: "wait1")?.cgImage, let image2 = UIImage(named: "wait2")?.cgImage, let image3 = UIImage(named: "wait3")?.cgImage else {
            return
        }
        let images = [image1, image2, image3]
        
        if device.canvas.createAnimation(images: images, anchor: .bottomRight, xOffset: 0, yOffset: 0, duration: 3000) {
            device.canvas.commit()
        }
    }
    
    
    // moves the animation to a random point
    @IBAction func moveAnimation(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        let randomPoint = randomPoint()
        if device.canvas.moveAnimation(x: Int(randomPoint.x), y: Int(randomPoint.y)) {
            device.canvas.commit()
        }
    }
    
    // remove the animation
    @IBAction func removeAninimation(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        if device.canvas.removeAninimation() {
            device.canvas.commit()
        }
    }
    
    // draws an image (glasses) and draws a rounded rectangle.
    @IBAction func drawBackground(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        let midx = (device.canvas.WIDTH / 2)
        let midy = (device.canvas.HEIGHT / 2)
        let rectWidth = 200
        let rectHeight = 40
        let rectX = midx - (rectWidth / 2)
        let rectY = midy - (rectHeight / 2)
        

        let color = UIColor.green.cgColor
        device.canvas.drawRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight, cornerRadius: 6, borderWidth: 3, borderColor: color, fillColor: nil)
        
        
        if let cgImage = UIImage(named: "glasses")?.cgImage {
            device.canvas.drawBackground(image: cgImage, x: midx - (cgImage.width/2), y: midy + 100)
        }
        
        device.canvas.commit()
    }
    
    // clears all the screen from everything including background
    @IBAction func clearAll(sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if !startControl(device: device, layout: .canvas) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        device.canvas.clear(shouldClearBackground: true)
        device.canvas.commit()
    }
    
    @IBAction func showScrollingText(_ sender: Any) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
                        
        if !startControl(device: device, layout: .scroll) {
            print("ERROR: Unable to gain control of the device")
            return
        }
        
        if autoScroller == nil {
            autoScroller = ScrollLayout.AutoScroller(stringToScroll: "The text can also scroll like a teleprompter with the scroll layout. This layout also supports several configuration options such as font size and scroll speed.", duration: 1000)
            autoScroller?.start()
            autoScroller?.delegate = self
        } else {
            autoScroller?.clear()
            autoScroller = nil
        }
    }
    
    
    // on detection of a single tap, displays the words "tap detected" for 4 seconds.
    override func onTap(notification: Notification) {
        guard let device = UltraliteManager.shared.currentDevice else {
            return
        }
        
        if let taps = notification.userInfo?["tap"] as? Int64, taps == 1 {
            
            if let tapTextHandle = tapTextHandle {
                _ = device.canvas.removeText(id: tapTextHandle)
            }
            
            tapTextHandle = device.canvas.createText(text: "tap detected", textAlignment: .center, textColor: .white, anchor: .bottomCenter, xOffset: 0, yOffset: 0)
            device.canvas.commit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) { [weak self] in
                if let tapTextHandle = self?.tapTextHandle {
                    _ = device.canvas.removeText(id: tapTextHandle)
                    device.canvas.commit()
                    self?.tapTextHandle = nil
                }
            }
        }
    }
    
    // random point
    func randomPoint() -> CGPoint {
        let x = Int.random(in: 0..<(640 - 100))
        let y = Int.random(in: 0..<(480 - 100))
        return CGPoint(x: x, y: y)
    }
}

extension ViewController: AutoScrollerDelegate {
    
    func done() {
        autoScroller?.clear()
        autoScroller = nil
    }
}

