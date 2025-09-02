# Here are the test and example for Decoder and Data Converter part of the zaudio

Because the test of these component requires audio files, I don't seem to find a way to test the Decoder and DataConverter type within a single test block, but to ensure my implementation is correct, I have written some examples code, doubling as the examples for using zaudio with low level API. Including:

- playback_sine (showing the simple stereo set up for playing a sine with circular panning effect)
- playback_mp3 (showing how to use the decoder to play samples)
- playback_memory (same as playback_mp3, for testing purpose)
- direct_decoder_access (demonstrate how to decode and access sample without an engine)
- data_converter_test (demonstrate how to use the DataConverter to change format)

Simply type `zig build run` should able to compile the projects, the three examples will plays the audio file accordingly, the last two example has no observable result, but validations to ensure the library works correctly.