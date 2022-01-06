# process_offsite_audio
Code for data organization and quality control of clinical interview audio, currently focused on minimum necessary steps for initial use by U24 sites. The audio side of the pipeline converts/renames any new interview audio files and extracts QC measures from these files. It then handles automatic upload of acceptable audio to TranscribeMe, along with emailing documentation to the lab. The transcript side of the pipeline analogously handles pulling returned transcripts back to the server, integrating with the existing dataflow for sites to review redaction quality and share anonymized data with the larger study. It also includes email updates and computation of quality control metrics on the returned transcripts, for monitoring of the entire data collection process. 

This repository is a prerelease of Baker Lab code, made publicly viewable for the purposes of testing on collaborator machines. Contact mennis@g.harvard.edu with any unanswered questions.

### Setup
The code requires ffmpeg and python3 to be installed, as well as use of standard bash commands. For the email alerting to work, the sendmail command must be configured. The python package dependencies can be found in the setup/audio_process.yml file, with the exception of soundfile and librosa. If Anaconda3 is installed this file can be used directly to generate a usable python environment. 

<details>
	<summary>For initial setup on the ProNet development server, the following steps were taken:</summary>

First, I installed Anaconda -
* wget https://repo.anaconda.com/archive/Anaconda3-5.3.1-Linux-x86_64.sh
* bash Anaconda3-5.3.1-Linux-x86_64.sh 
	* (Answered yes to bashrc question, no to Visual Studio question, other prompts kept as default by just pressing enter)
* rm Anaconda3-5.3.1-Linux-x86_64.sh
* source .bashrc

Note ffmpeg, the other main dependency, was already working on the machine.

Then I setup the repository with included Anaconda environment -
* cd /opt/software
* git clone https://github.com/dptools/process_offsite_audio.git 
* cd process_offsite_audio/setup
* conda env create -f audio_process.yml
* conda activate audio_process
* pip install soundfile
* pip install librosa
* cd ..

Because of the way that passwords are stored, the code should generally be run by the same account that completes this installation.
</details>

The pipeline expects to work within a PHOENIX data structure matching the conventions described in the U24 SOP. 

<details>
	<summary>The basic input assumptions are as follows:</summary>
The audio side looks for interviews/psychs and interviews/open datatypes on the PROTECTED side of raw, which should be (exclusively) populated by Lochness. Any data under these folders is expected to match one of two conventions - either a folder produced by Zoom uploaded as is or a standalone audio file recorded using a single physical device named according to the convention YYYYMMDDHHMMSS.WAV. For the Zoom interviews, the code currently only processes the single combined audio file provided. 

The transcript side of the pipeline primarily relies on outputs from the audio side. It also expects a box_transfer/transcripts folder on the top level of the PHOENIX structure's PROTECTED side, to facilitate transfering completed transcripts to the corresponding sites for correctness review. In finalizing the transcripts that are subsequently returned by sites, it looks for interviews/transcripts datatype on the PROTECTED side of raw. 

The code also requires a metadata file under the study level of GENERAL, and will only process a particular patient ID if that ID appears as a row in the metadata file containing a valid consent date (per Lochness guidelines). If there are issues encountered with the basic study setup appropriate error messages will be logged.

Note the pipeline only ever reads from raw datatypes. All pipeline outputs are saved/modified as processed datatypes. The deidentified data that make it under the GENERAL side of processed will subsequently be pushed by Lochness to the NDA data lake.
</details>

### Use
The pipeline will generally be run using the two wrapping bash scripts provided in the top level of this repository, with the path to a settings file as the single argument. The audio_process conda environment should be activated prior to launching these scripts. For an example of how to put together a settings file for a particular study, see example_config.sh. The full audio side pipeline can then be run by using:

	bash interview_audio_process.sh example_config.sh

The transcript side of the pipeline can be run using the same settings file with:

	bash interview_transcript_process.sh example_config.sh

Each major step is initiated by the pipeline using a script in the individual_modules folder, see this folder if specific steps need to be run independently. 

### Audio Processing Details
The major steps of the audio side of the pipeline are:
1. Identify new audio files in raw by checking against existing QC outputs
2. Convert any new audio files in raw to WAV format if not already, saving WAV copies of all new audio files on the processed side of PROTECTED
3. Rename the new audio file copies to match SOP convention
4. Run audio QC on the new audio files
5. Check for sufficient volume levels and acceptable interview lengths
6. Upload all approved new audio files to TranscribeMe
7. Send email listing all files that were newly processed, indicating which were successfully uploaded to TranscribeMe and otherwise documenting possible issues

<details>
	<summary>Aside from the renamed and converted audio files that can be used directly for future processing by U24 code, the primary immediate outputs of this code are the audio QC features:</summary>
 
The main audio QC output CSV provides one row per interview with the following summary stats -
* Metadata for DPDash formatting
* Length of audio (in minutes)
* Overall volume (in dB)
* Standard deviation of amplitude (related to variance of volume)
* Mean of spectral flatness computed by librosa

One such CSV will be generated per subject ID, separately for the open and psychs interview types. These CSVs are saved on the GENERAL side of processed, and thus will be included in the data aggregation for sharing. They are intended to be used with the DPDash interface for study monitoring.

The audio QC processing also includes a sliding window QC operation, which computes decibel level and mean flatness in each designated bin (3 second sliding window with no overlap), creating one output file per interview audio. These outputs can be used for further processing but are kept on the PROTECTED side and so not currently shared with the wider group. They are used by the pipeline to check processing status among the raw audios.
</details>

<details>
	<summary>For security review, the audio files are pushed to TranscribeMe using the following process:</summary>

We connect to the TranscribeMe server via SFTP. The pySFTP python package, a wrapper around the Paramiko package specific for SFTP is used to automate this process. The host is sftp.transcribeme.com. The standard port 22 is used. The username is provided as a setting to the code, but will generally be one account for all sites on the ProNet side and one account for all sites on the Prescient side, with set up of this facilitated by TranscribeMe. The account password is input using a temporary environment variable. It was previously prompted for using read -s upon each run of the code, but for the purposes of automatic scheduled jobs, the password may now be stored in a hidden file with restricted permissions on a PROTECTED portion of our machine instead. 

Note that once the transcript side of the pipeline has detected a returned transcript on this SFTP server, the corresponding uploaded audio is deleted by our code on TranscribeMe's end using the same SFTP package.

If additional details are needed, please reach out. We can also put you in touch with the appropriate person at TranscribeMe to document security precautions on their end. 
</details>

### Transcript Processing Details
The major steps of the transcript side of the pipeline are:
1. Check the TranscribeMe server for any pending transcriptions
2. For transcripts that are newly available, pull them back onto our server and delete the corresponding audio from TranscribeMe's server
3. Copy any transcripts marked for manual screening by the sites into the necessary folder for push to Box/Mediaflux
4. Copy any transcripts that have been newly returned by the sites after review into the final PROTECTED transcripts folder
5. Create redacted versions of any newly finalized transcripts under the GENERAL side
6. Convert the newly redacted transcripts to CSV format
7. Compute transcript QC stats across the redacted transcripts
8. Send email listing all the transcripts that were successfully pulled from TranscribeMe and those still awaiting transcription, as well as the transcripts newly returned from manual review by sites 

Note that the Box/Mediaflux push described in step 3 is done by separate code written by the ProNet/Prescient teams respectively. The return of reviewed transcripts is handled by Lochness. Sites will go through any transcripts sent to them, mark any PII missed by TranscribeMe with curly braces (per TranscribeMe convention), and move to a folder indicating completed review (which Lochness can then pull from). Currently the code sends all transcripts for review by sites, but per the U24 SOP the code will eventually be updated to send a random subset only for review. Anything not sent for review will inmediatly undergo steps #5+. 

<details>
	<summary>The primary outputs of this side of the pipeline include the transcripts at various stages of processing, as well as the final derived QC measures, as detailed here:</summary>

All transcripts that contain PII are kept on the PROTECTED side, and thus will not be shared with the wider group. Transcripts that have passed over or completed the manual site review are kept in main transcripts folder of processed. For those transcripts that are sent for site review, a copy as it was returned by TranscribeMe can be found in a prescreening subfolder, so if changes are made by sites it will remain possible to refer back to the original transcript if necessary. 

Because PII is enclosed by curly braces as part of the transcription protocol, it is straightforward to generate a version of each transcript where the PII is actually removed (each such word replaced by REDACTED). This version is put on the GENERAL side of processed for syncing to the data lake. Also included is the CSV version of the transcript for easier processing by automated methods, where each row is a line of the transcript containing speaker ID, timestamp, and text as the main columns.

Using these CSVs, the following transcript QC metrics are computed - 
* Metadata for DPDash formatting
* Number of unique speaker IDs used by TranscribeMe
* For each of the first three speaker IDs (S1-S3), the following counting stats
	* Total number of sentences
	* Total number of words
	* Smallest number of words in a sentence
	* Largest number of words in a sentence
* Number of times the audio was marked inaudible
* Number of times a transcript portion was marked as uncertain
* Number of times crosstalk was marked
* Number of words redacted
* Total number of commas appearing (related to disfluency markers)
* Total number of dashes appearing (related to disfluency markers)
* Timestamp for the start of the final sentence, in minutes
* Shortest gap between the starts of two subsequent sentences, in seconds
* Longest gap between the starts of two subsequent sentences, in seconds
* The shortest and longest gaps weighted by the number of words in the intervening sentence

One such CSV will be generated per subject ID, separately for the open and psychs interview types. These CSVs are saved on the GENERAL side of processed, and thus will be included in the data aggregation for sharing. They are intended to be used with the DPDash interface for study monitoring.
</details>

Interfacing with TranscribeMe is done using the same SFTP protocol as described in the audio section. 

### Next Steps
* Move from ProNet development server to ProNet production server
* Complete security review and prod server testing
* Implement tracking of audio language for TranscribeMe
* Implement the random selection stage for site review of returned transcripts
* Handle equipment/software edge cases (such as site using Microsoft Teams?)
* Finalize plans for code monitoring and manual intervention protocols
* Replicate setup for Prescient

Aim is to launch this workflow for real data collection at sites beginning in late January 2022. 
