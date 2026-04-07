//
//  VoicePreviewPlayer.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import AVFoundation
import Foundation

@Observable
final class VoicePreviewPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    var isPlaying = false
    var lastError: String?

    var durationSeconds: TimeInterval {
        player?.duration ?? 0
    }

    func prepare(url: URL) {
        stop()
        lastError = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
        } catch {
            lastError = error.localizedDescription
            player = nil
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
