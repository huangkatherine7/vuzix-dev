# Goal: Every Day Wear
In this repo, we integrate Vuzix Z100 with iOS to create a variety of functionality geared towards the AR glasses use case of every-day wear.

This repo is based on the [Ultralite SDK Sample for iOS application](https://github.com/Vuzix/ultralite-sdk-ios-sample) built using the [Ultralite SDK for iOS](https://github.com/Vuzix/UltraliteSDK-releases-iOS). 

# Set up
Clone the repository. Then, in Finder, double click on `SampleApp.xcodeproj` to open the project in Xcode. Connect your iPhone via USB to develop (make sure iPhone is set in Developer Mode). Upon opening the app, it will automatically pair with your Vuzix.

# Applications

## Simple Timer

### How to Use
Click the "Create Hello World" button to trigger `startSpeechRecognition` (in `ViewController`). Voice input: "Set a `n` minute timer."

### How It Works
This phrase is passed to a llama-3.1-8B model (hosted on [build.nvidia.com](https://build.nvidia.com/meta/llama-3_1-8b-instruct)). You may have to change the `apiKey` variable in the `parseTimerCommand` function.

The LLM extracts the key number `n` and sets an `n` minute timer, which is displayed counting down on the Vuzix display. When the timer finishes, the words "Time's up!" is displayed and the app also sends a notification.

## Issues
No ending condition yet...crashes after infinite listening

## Other ideas
1. GPT wrapper
1. add to notes
1. add to calendar
1. send message (text, discord)
1. Spotify? How to design to see full playlist
