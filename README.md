# process_offsite_audio
This repository is a prerelease of Baker Lab code, made publicly viewable for the purposes of testing on collaborator machines.

Code for quality control and feature extraction from offsite interview (Zoom) audio as well as stand alone audio recorded using a single device onsite. Currently focusing on minimum steps for initial use by U24 sites. This repo includes a module for converting/renaming any new interview audio files, and a module for running audio QC to compile both a summary CSV across interviews and individual CSVs per interview with sliding window QC output. It then handles automatic upload of acceptable audio files to TranscribeMe, along with emailing documentation to the lab. For offsites, the code focuses only on the single combined audio file Zoom returns, to ensure quality for upload to TranscribeMe. 

For an example of how to put together a settings file for a particular project, see example_config.sh. The full audio side pipeline can then be run by using:

	bash interview_audio_process.sh example_config.sh

The main audio QC output CSV found on the top level of the patient's GENERAL side interview/processed folder includes the following features:
* Metadata for DPDash formatting
* Length of audio (in minutes)
* Overall volume (in dB)
* Standard deviation of amplitude (related to variance of volume)
* Mean of spectral flatness computed by librosa

The sliding window QC computes decibel level and mean flatness in each designated bin (3 second sliding window with no overlap), creating one output file per interview audio, found under a subfolder of processed on the PROTECTED side along with the converted/renamed audio files sorted by transcription status.

Code now also exists for the transcript side of the pipeline, which currently just pulls newly available transcripts from the TranscribeMe server into a transcripts subfolder of the patient's PROTECTED side interview/processed folder. Upon successfully pulling a transcript, it also deletes the matching raw audio from TranscribeMe's server, moves the transcript into an archive subfolder on TranscribeMe's server, and moves the raw audio on our server from the pending_audio subfolder to the completed_audio subfolder. In this process a list of successful pulls and remaining pending transcripts is compiled for email alert. 

The transcript side of the pipeline can be run using the same settings file by using:

	bash interview_transcript_process.sh example_config.sh

It requires no additional setup beyond what was already required for the audio side (see below) 

### Setup
For initial setup on the ProNet server, the following steps were taken. First, I installed Anaconda:
* wget https://repo.anaconda.com/archive/Anaconda3-5.3.1-Linux-x86_64.sh
* bash Anaconda3-5.3.1-Linux-x86_64.sh 
	* (Answered yes to bashrc question, no to Visual Studio question, other prompts kept as default by just pressing enter)
* rm Anaconda3-5.3.1-Linux-x86_64.sh
* source .bashrc

Note ffmpeg, the other main dependency, was already working on the machine.

Then I setup the repository with included Anaconda environment:
* cd /opt/software
* git clone https://github.com/dptools/process_offsite_audio.git 
* cd process_offsite_audio/setup
* conda env create -f audio_process.yml
* conda activate audio_process
* pip install soundfile
* pip install librosa
* cd ..

From there, I just confirmed the settings in example_config.sh matched what we wanted for our test run and ran the code as described above. 

For future use, it should only be necessary to activate the conda environment and then run the code. If not done from my account it will likely require root access due to the setup of the password file. 

### Next Steps
On the audio side, there are some small remaining logistics to sort out:
* In the most recent Zoom update naming convention of the saved recordings changed a bit, code will need to be updated accordingly
* The summary email to the group and email alert to TranscribeMe does not send on ProNet server because the mail command is not configured
* Confirm security situation - do we sufficiently handle the TranscribeMe account password?

On the transcript side, a number of steps remain to be worked out:
* Finalize TranscribeMe file format/notation conventions for this project
* Automatically make a transcript copy with PII marked by TranscribeMe actually redacted
* Get redacted transcript copies to sites for approval (integrate with Lochness)
* Finalize redacted transcripts returned by the sites for sharing, put final copy on GENERAL side
* Create CSVs for analysis from the final transcripts - one as is and one with additional cleaning for direct input to NLP models
* Run TranscriptQC code on the returned transcripts (can first make a few interview-specific adaptations)
