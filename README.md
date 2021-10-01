# process_offsite_audio
Code for quality control and feature extraction from offsite interview (Zoom) audio. Currently focusing on minimum steps for initial use by U24 sites. This repo includes a module for decrypting any new offsite audio files, and a module for running audio QC to compile both a summary CSV across interviews and indiviudal CSVs per interview with sliding window QC output (2 minutes per bin). The code focuses only on the single combined audio file Zoom returns, to ensure quality for upload to TranscribeMe - use of speaker separated audio remains as a future goal. Immediate next steps will be to put together the rest of the single audio processing pipeline for the offsite use case. See the process_audio_diary pipeline for more info on what that will ultimately look like. 

Bash scripts to run the modules for an entire study are found under the individual_modules subfolder. Study name can be set at the top of these files (to be moved to config). These scripts utilize the code (primarily Python) under individual_modules/functions_called. 

The decryption module requires the use of Harvard's cryptease tool, and manual entry of the appropriate study passphrase. The audio QC script works from outputs of the decryption module. As the wrapping pipeline is not yet implemented, the decrypted_audio folder placed under each patient's offsite_interview/processed folder will need to be deleted manually when the code is done. 

No outputs to date are fully cleaned of PII, so they can all be found under the PROTECTED side of the patient's offsite_interview/processed folder. The main audio QC output found on the top level of that folder contains the following features:
* Length of audio (in minutes)
* Overall volume (in dB)
* Standard deviation of amplitude (related to variance of volume)
* Mean of spectral flatness computed by librosa
* Max of spectral flatness computed by librosa
* There is also a check that the file is mono (expected here)

The sliding window QC computes decibel level and mean flatness in each designated bin.