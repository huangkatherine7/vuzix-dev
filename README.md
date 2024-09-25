# Goal: Every Day Wear
In this repo, we integrate Vuzix Z100 with iOS to create a variety of functionality geared towards the AR glasses use case of every-day wear.

This repo is based on the [Ultralite SDK Sample for iOS application](https://github.com/Vuzix/ultralite-sdk-ios-sample) built using the [Ultralite SDK for iOS](https://github.com/Vuzix/UltraliteSDK-releases-iOS). 

# Set up
Clone the repository. Then, in Finder, double click on `SampleApp.xcodeproj` to open the project in Xcode. Connect your iPhone via USB to develop (make sure iPhone is set in Developer Mode). Upon opening the app, it will automatically pair with your Vuzix.

# Applications
Click the "Create Hello World" button to start listening.

# Dev Notes
Focus on synchronous instant execution tasks (ie. llm queries good, locally hosted timer bad) so I don't have to deal with multithread.

## LLM Queries
Ask any natural language query. For example: `Tell me a joke about cats`.

### Issues
1. Inference time is really long, nothing else can run until the inference returns so it may clog things?

## Simple Timer

### How to Use
Click the "Create Hello World" button to trigger `startSpeechRecognition` (in `ViewController`). Voice input: "Set a `n` minute timer."

### How It Works
This phrase is passed to a llama-3.1-8B model (hosted on [build.nvidia.com](https://build.nvidia.com/meta/llama-3_1-8b-instruct)). You may have to change the `apiKey` variable in the `parseTimerCommand` function.

The LLM extracts the key number `n` and sets an `n` minute timer, which is displayed counting down on the Vuzix display. When the timer finishes, the words "Time's up!" is displayed and the app also sends a notification.

### Issues/TODO
1. Can't do timer and llm query at same time (timer has to finish for llm result to be displayed). Also timer pauses when new LLM query begins, and then resumes after the llm func returns.
2. __Change to somehow call the iphone API then? So it's asynchronous?__
1. (MAYBE OLD ISSUE??) No ending condition yet...crashes after infinite listening

## Other ideas
1. add to notes app
1. add to calendar
1. send message (text, discord)
1. Spotify? How to design to see full playlist
