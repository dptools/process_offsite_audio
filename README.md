# process_offsite_audio
This repository is a prerelease of Baker Lab code, made publicly viewable for the purposes of testing on collaborator machines.

Code for quality control and feature extraction from offsite interview (Zoom) audio. Currently focusing on minimum steps for initial use by U24 sites. This repo includes a module for decrypting any new offsite audio files, and a module for running audio QC to compile both a summary CSV across interviews and individual CSVs per interview with sliding window QC output. It then handles automatic upload of acceptable audio files to TranscribeMe, along with emailing documentation to the lab. The code focuses only on the single combined audio file Zoom returns, to ensure quality for upload to TranscribeMe - use of speaker separated audio remains as a future goal. Immediate next steps will be to put together the transcript side of the processing pipeline for the offsite use case. See the process_audio_diary pipeline for more info on what that will ultimately look like. 

For setup of the code for a particular project, see example_config.sh. The full audio side pipeline can then be run by using:

	bash interview_audio_process.sh example_config.sh

The main audio QC output CSV found on the top level of the patient's GENERAL side offsite_interview/processed folder includes the following features:
* Metadata for DPDash formatting
* Length of audio (in minutes)
* Overall volume (in dB)
* Standard deviation of amplitude (related to variance of volume)
* Mean of spectral flatness computed by librosa

The sliding window QC computes decibel level and mean flatness in each designated bin, creating one output file per interview audio, found under a subfolder of processed.