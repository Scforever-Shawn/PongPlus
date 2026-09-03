extends Node

var audio_players = {}

func _ready():
    # Setup retro sound players using synthesized square waves
    audio_players["hit"] = create_player(generate_square_wave(440.0, 0.1))
    audio_players["parry"] = create_player(generate_square_wave(880.0, 0.2))
    audio_players["score"] = create_player(generate_square_wave(220.0, 0.5))
    audio_players["powerup"] = create_player(generate_square_wave(660.0, 0.3))
    audio_players["break"] = create_player(generate_square_wave(110.0, 0.4))
    
    for key in audio_players.keys():
        add_child(audio_players[key])

func create_player(stream: AudioStream) -> AudioStreamPlayer:
    var player = AudioStreamPlayer.new()
    player.stream = stream
    player.process_mode = Node.PROCESS_MODE_ALWAYS # keep playing even during hit pause!
    return player

func play_sound(name: String):
    if audio_players.has(name):
        audio_players[name].play()

func generate_square_wave(freq: float, duration: float) -> AudioStreamWAV:
    var stream = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 44100
    
    var sample_count = int(stream.mix_rate * duration)
    var data = PackedByteArray()
    data.resize(sample_count * 2) # 2 bytes per sample for 16-bit
    
    var period_samples = stream.mix_rate / freq
    
    for i in range(sample_count):
        var phase = fmod(i, period_samples) / period_samples
        # Simple volume envelope (fade out)
        var vol = 1.0 - (float(i) / sample_count)
        # Square wave
        var val = 16000 * vol if phase < 0.5 else -16000 * vol
        var val_int = int(val)
        
        # 16-bit little endian encoding
        data[i*2] = val_int & 255
        data[i*2+1] = (val_int >> 8) & 255
        
    stream.data = data
    return stream
