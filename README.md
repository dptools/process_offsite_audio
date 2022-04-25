# U24 Interview AV Data Aggregation and Quality Control
Code for data organization and quality control of clinical interview audio and video recorded from Zoom, currently focused on minimum necessary steps for initial use by U24 sites. This repository is a prerelease of Baker Lab code, made publicly viewable for the purposes of testing on collaborator machines. Contact mennis@g.harvard.edu with any unanswered questions.

The audio side of the pipeline converts/renames any new mono interview audio files and extracts QC measures from these files. It then handles automatic upload of acceptable audio to TranscribeMe, along with emailing documentation to the group. It does not currently process speaker-specific audio files.  

The transcript side of the pipeline analogously handles pulling returned transcripts back to the server, integrating with the existing dataflow for sites to review redaction quality and share anonymized data with the larger study. It also includes email updates and computation of quality control metrics on the returned transcripts, for monitoring of the entire data collection process. 

The video portion of the pipeline identifies unprocessed video files in valid Zoom interview folders and extracts one frame from every 4 minutes of each video. These frames are then run through a lightweight face detection model from PyFeat, to provide some video quality control at low computational cost. The same script also gets metadata information about the interview (e.g. converting to study day number) in order to fill out a DPDash-formatted QC CSV analogous to those created for audio and transcripts. 

### Table of Contents
1. [Setup](#setup)
	- [Input Data Requirements](#inputs)
2. [Use](#use)
	- [Architecture Diagram](#diagram)
	- [Common Issues](#issues)
3. [Audio Processing Details](#audio)
	- [Security](#security)
4. [Transcript Processing Details](#transcript)
	- [TranscribeMe Conventions](#transcribeme)
5. [Video Processing Details](#video)
6. [Examples Outputs](#outputs)
	- [Emails](#email)
	- [DPDash CSVs](#dpdash)
7. [Status](#status)
	- [Pronet](#pronet)
	- [Prescient](#prescient)
8. [Next Steps](#todo)
	- [Code](#code)
	- [Logistics](#logistics)

### Setup <a name="setup"></a>
The code requires ffmpeg and python3 to be installed, as well as use of standard bash commands. For the email alerting to work, the mailx command must be configured. The python package dependencies can be found in the setup/audio_process.yml file, with the exception of soundfile and librosa on the audio side and pyfeat on the video side. If Anaconda3 is installed this file can be used directly to generate a usable python environment. 

<details>
	<summary>For initial setup on the Pronet development server, the following steps were taken:</summary>

First, I installed Anaconda -
* wget https://repo.anaconda.com/archive/Anaconda3-5.3.1-Linux-x86_64.sh
* bash Anaconda3-5.3.1-Linux-x86_64.sh 
	* (Answered yes to bashrc question, no to Visual Studio question, other prompts kept as default by just pressing enter)
* rm Anaconda3-5.3.1-Linux-x86_64.sh
* source .bashrc

Note ffmpeg, the other main dependency, was already working on the machine. The sendmail command has also now been installed/configured by support.  

Then I setup the repository with included Anaconda environment -
* cd /opt/software
* git clone https://github.com/dptools/process_offsite_audio.git 
* cd process_offsite_audio/setup
* conda env create -f audio_process.yml
* conda activate audio_process
* pip install soundfile
* pip install librosa
* cd ..

Because of the way that TranscribeMe passwords are stored, the audio and transcript code should generally be run by the same account that completes this installation.

When the video code was added, I also added PyFeat to the environment. However the development machine was unable to install PyFeat directly due to resource limitations, so a few PyFeat dependencies were installed separately first. The full list of steps I took were - 
* conda activate audio_process
* pip install opencv-python
* pip install torch --no-cache-dir
* pip install py-feat
</details>

##### Input Data Requirements <a name="inputs"></a>

The pipeline expects to work within a PHOENIX data structure matching the conventions described in the U24 SOP. 

<details>
	<summary>The basic input assumptions are as follows:</summary>

The audio side looks for interviews/psychs and interviews/open datatypes on the PROTECTED side of raw, which should be (exclusively) populated by Lochness. Any data under these folders is expected to match one of two conventions - either a folder produced by Zoom uploaded as is or a standalone audio file recorded using a single physical device named according to the convention YYYYMMDDHHMMSS.WAV. For the Zoom interviews, the code currently only processes the single combined audio file provided. 

The transcript side of the pipeline primarily relies on outputs from the audio side. It also expects a box_transfer/transcripts folder on the top level of the PHOENIX structure's PROTECTED side, to facilitate transfering completed transcripts to the corresponding sites for correctness review. In finalizing the transcripts that are subsequently returned by sites, it looks for interviews/transcripts datatype on the PROTECTED side of raw. 

The code also requires a metadata file under the study level of GENERAL, and will only process a particular patient ID if that ID appears as a row in the metadata file containing a valid consent date (per Lochness guidelines). If there are issues encountered with the basic study setup appropriate error messages will be logged.

Note the pipeline only ever reads from raw datatypes. All pipeline outputs are saved/modified as processed datatypes. The deidentified data that make it under the GENERAL side of processed will subsequently be pushed by Lochness to the NDA data lake.
</details>

[For more information, the Data Transfer SOP can be found here.](https://docs.google.com/document/d/1sVHIB313CLfmGuy6Sbk28kElw7pqp0wYjF_dEFCiY4g/edit#heading=h.6j7n1rfryn4k)

### Use <a name="use"></a>
The pipeline will generally be run using the three wrapping bash scripts provided in the top level of this repository, with the path to a settings file as the single argument. The audio_process conda environment should be activated prior to launching these scripts. For an example of how to put together a settings file for a particular study, see example_config.sh. The full audio side pipeline can then be run by using:

	bash interview_audio_process.sh example_config.sh

The transcript side of the pipeline can be run using the same settings file with:

	bash interview_transcript_process.sh example_config.sh

Finally, the video side of the pipeline can again be run using the same settings file with:

	bash interview_video_process.sh example_config.sh

For use on Pronet, config files are already generated for each site in the Pronet_site_configs subfolder, and can be edited as needed. The all_sites_cron_script.sh runs the audio, transcript, and video sides of the pipeline for each of these configs, used for running the code across sites (currently on the Pronet dev server at 2pm daily).

##### Architecture Diagram <a name="diagram"></a>
Each major step is initiated by the pipeline using a script in the individual_modules folder, see this folder if specific steps need to be run independently. 

<details>
	<summary>Click here for an overview of data flow and the use of different modules through the pipeline</summary>

![architecture diagram](./images/InterviewU24Diagram.png) 

</details>

Additional details on each step are provided below. 

For the U24 study, we expect two different types of interviews (open and psychs), which are both handled by the full pipeline and will both be included in the same email alerts, but are processed independently by each module with outputs saved separately. Each participant will be given 2 open interviews and 9 psychs interviews. The open interviews will be about 20 minutes, while the psychs interviews will be about 30 minutes. 

##### Common Issues <a name="issues"></a>
Most times that an interview is not processed when expected there is an issue with violating naming conventions, either because the data was incorrectly placed so Lochness could not pull it, or the files within the Zoom folder were renamed so that this audio code could not recognize it. It has also been common during the testing phase for subject IDs to be missing metadata - if there is a new subject ID it needs to be entered in REDCap before the code can process.

Outside of users not following the SOP, there are a few likely avenues for possible bugs that should be monitored:
* Folder permissions issues or low storage availability on the data aggregation server
* TranscribeMe typos or otherwise inconsistencies in provided transcripts - could also be unanticipated problems with foreign languages
* Stopping and starting of recording in the same Zoom interview, whether intentionally or due to host disconnects

If a code issue needs to be investigated, log files are automatically saved under a subfolder of the repository install, organized by site and labeled with pipeine name and Unix run time. 

### Audio Processing Details <a name="audio"></a>
The major steps of the audio side of the pipeline are:
1. Identify new audio files in raw by checking against existing QC outputs
2. Convert any new audio files in raw to WAV format if not already, saving WAV copies of all new audio files on the processed side of PROTECTED
3. Rename the new audio file copies to match SOP convention
4. Run audio QC on the new audio files
5. Check for sufficient volume levels and acceptable interview lengths
6. Upload all approved new audio files to TranscribeMe (with temporarily added site-based language marker, to assist TranscribeMe in assigning transcribers)
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

##### Security <a name="security"></a>
<details>
	<summary>For security review, the audio files are pushed to TranscribeMe using the following process:</summary>

We connect to the TranscribeMe server via SFTP. The pySFTP python package, a wrapper around the Paramiko package specific for SFTP is used to automate this process. The host is sftp.transcribeme.com. The standard port 22 is used. The username is provided as a setting to the code, but will generally be one account for all sites on the Pronet side and one account for all sites on the Prescient side, with set up of this facilitated by TranscribeMe. These accounts are created only to be used with this code and will serve no other purpose.

The account password is input using a temporary environment variable. It was previously prompted for using read -s upon each run of the code, but for the purposes of automatic scheduled jobs, the password may now be stored in a hidden file with restricted permissions on a PROTECTED portion of our machine instead. Anyone who could access this file necessarily must also have access to the raw files themselves, so use of the TranscribeMe password would provide no additional benefit. 

Note that once the transcript side of the pipeline has detected a returned transcript on this SFTP server, the corresponding uploaded audio is deleted by our code on TranscribeMe's end using the same SFTP package. 

</details>

If additional details are needed, please reach out. We can also put you in touch with the appropriate person at TranscribeMe to document security precautions on their end.

### Transcript Processing Details <a name="transcript"></a>
The major steps of the transcript side of the pipeline are:
1. Check the TranscribeMe server for any pending transcriptions
2. For transcripts that are newly available, pull them back onto our server and delete the corresponding audio from TranscribeMe's server
3. Copy any transcripts marked for manual screening by the sites into the necessary folder for push to Box/Mediaflux
4. Copy any transcripts that have been newly returned by the sites after review into the final PROTECTED transcripts folder
5. Create redacted versions of any newly finalized transcripts under the GENERAL side
6. Convert the newly redacted transcripts to CSV format
7. Compute transcript QC stats across the redacted transcripts
8. Send email listing all the transcripts that were successfully pulled from TranscribeMe and those still awaiting transcription, as well as the transcripts newly returned from manual review by sites 

Note that the Box/Mediaflux push described in step 3 is done by separate code written by the Pronet/Prescient teams respectively (latter remains to be implemented). The return of reviewed transcripts is handled by Lochness. Sites will go through any transcripts sent to them, mark any PII missed by TranscribeMe with curly braces (per TranscribeMe convention), and move to a folder indicating completed review (which Lochness can then pull from). Currently the code sends all transcripts for review by sites, but per the U24 SOP the code will eventually be updated to send a random subset only for review. Anything not sent for review will immediatly undergo steps 5 and on. 

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

##### TranscribeMe Conventions <a name="transcribeme"></a>
We receive full verbatim transcriptions from TranscribeMe, with sentence level timestamps and speaker identification included. As mentioned above, any PII in the transcription is marked by curly braces. 

[To properly interpret the full verbatim transcriptions, please see TranscribeMe's (English) style guide here.](https://www.dropbox.com/s/lo19xzux3n16pbn/TranscribeMeFullVerbatimStyleGuide.pdf?dl=0)

### Video Processing Details <a name="video"></a>
The major steps of the video side of the pipeline are:
1. Identify new video files in raw by checking against existing extracted frames
2. Extract 1 frame from every 4 minutes of any new raw video file, saving images in an interview-specific subfolder on the processed side of PROTECTED
3. Run PyFeat's basic face detection model, saving a corresponding CSV for each image
4. Use PyFeat outputs from across each interview along with study/interview metadata information to update DPDash-formatted video QC CSV on the processed side of GENERAL

<details>
	<summary>The primary output of this side of the pipeline is the DPDash CSV, although the extracted images and their corresponding PyFeat outputs could also be useful. The details of these outputs are as follows:</summary>

Because the DPDash CSV is saved on the processed side of GENERAL, it is pushed to the data lake. It is of course intended to be imported into DPDash for further monitoring. As per convention there is one CSV generated per subject ID and interview type, containing one row per interview. Besides the DPDash metadata columns, the QC columns include - 
* Number of frames extracted (will be the floor of interview minutes divided by 4)
* Minimum number of faces detected in an extracted frame
* Maximum number of faces detected in an extracted frame
* Average number of faces detected across extracted frames
* Minimum confidence score across faces that were detected
* Maximum confidence score across faces that were detected
* Average confidence score across faces that were detected
* Minimum area across faces that were detected (area computed by multiplying the height and width variables returned by PyFeat)
* Maximum area across faces that were detected
* Average area across faces that were detected

On the processed side of PROTECTED, the extracted frames will remain so that more robust QC could be done if compute resources on another machine allow (it is not possible to load the standard face pose or action unit detection models on the Pronet development server at this time). The CSVs saved per image could also be of use for expanding what we provide in the final QC spreadsheet. These CSVs contain one row per detected face, with the follow features provided - 
* Face location X coordinate 
* Face location Y coordinate
* Face rectangle width
* Face rectangle height
* Detection confidence score

</details>

<details>
	<summary>For the Jena site that is not permitted to upload raw video to the data aggregation server, PyFeat will be run locally using a custom script. The following information about PyFeat was provided to Jena for security review, and may also be relevant for broader security review of this code:</summary>

PyFeat is a Python package built on top of PyTorch (a deep learning package). As we will be using the default provided models, it can be run offline once the package is fully installed. [It is open source if there is any need to review the code directly.](https://github.com/cosanlab/py-feat)

The output we will be obtaining with PyFeat is frame by frame information on how many faces were detected, and for each face the estimated coordinates of various facial landmarks as well as predicted current emotion. [This page gives a good depiction of the returned face information.](https://py-feat.org/content/plotting.html)

The output will then be saved as a CSV where each row corresponds to one face in one frame, and the columns are the aforementioned features. 

This would be run entirely locally here, and I would write a script that would handle the file management so that interview folders only go into Mediaflux when it has been confirmed that the video file has been removed and instead replaced with the PyFeat CSV. So the video file would never leave the machine, but the extracted feature CSV would get synced to Mediaflux and subsequently pulled to the data aggregation server by Lochness.

</details>

### Example Outputs <a name="outputs"></a>
As discussed above, there are a few different types of outputs generated by this code:
* Intermediate outputs that may be used for additional future processing steps, stored under PROTECTED/processed
* Final outputs that are stored under GENERAL/processed and subsequently pushed by Lochness to the data lake
* Communication, which includes email alerts for monitoring code status and interfaces on DPDash for checking data quality

In this section, examples of the most user-relevant outputs are provided from some of our mock interview test data, focusing on the "communication" category.

##### Emails <a name="email"></a>
These are the primary mode of communication for the pipeline. For each site a set of email addresses can be provided in the config file, and then site-specific updates on new interviews will be sent to the specified addresses upon each daily run of the code. The audio email is only sent if new audio files are processed for that site, and the transcript email is only sent if that site has newly processed transcripts (returned from TranscribeMe or from site review) or is actively awaiting transcripts from TranscribeMe. 

<details>
	<summary>Click here for an example of an audio update email</summary>

![audio email](./images/AudioEmail.png) 

</details>

<details>
	<summary>Click here for an example of a transcript update email from a new upload to TranscribeMe</summary>

![transcribeme email](./images/TranscriptEmail1.png) 

</details>

<details>
	<summary>Click here for an example of a transcript update email from a transcript newly returned from manual site redaction review</summary>

![review email](./images/TranscriptEmail2.png) 

</details>

The emails continue to be refined and their exact content may change.

##### DPDash CSVs <a name="dpdash"></a>
These are the primary outputs pushed to the data lake (besides the redacted transcripts), and also will be used for data quality monitoring once appropriate DPDash configurations are created. Audio, transcript, and video QC DPDash-formatted CSVs are generated for each subject ID and interview type with existing data. The DPACC team has also added tracking of these files into their data accounting script. 

Note the QC features have since been updated to round any floats for better display on DPDash, and some of the column names have been adjusted to ensure formatting is consistent. Filenames were also updated to meet new DPDash naming conventions (e.g. the site code needs to be just the two digits in the CSV filename). 

<details>
	<summary>Click here for an example snippet of the Pronet file accounting page on DPDash, now including rows that indicate availability of audio, transcript, and video QC outputs for each subject ID</summary>

![dpdash](./images/PronetFiles.png) 

</details>

<details>
	<summary>Click here for an example of an audio QC CSV</summary>

![audio qc](./images/AudioQC.png) 

</details>

<details>
	<summary>Click here for an example snippet of a transcript QC CSV, chosen because it detected a typo in the speaker identification in one of the transcripts (one line was attributed to S21). Note many additional transcript QC features were omitted from this image for legibility</summary>

![transcript qc](./images/TranscriptQC.png) 

</details>

<details>
	<summary>Click here for an example snippet of a video QC CSV. In this example there are no faces detected at the start of the video, but 2 faces as expected at the 5 minute mark (it is a short interview). Note some additional video QC features were omitted from this image</summary>

![video qc](./images/VideoQC.png) 

</details>

For more information on the specific features extracted as part of each of the above QC modules, see the associated "Processing Details" section above.

### Current Status <a name="status"></a>
Test data collection has begun across sites, awaiting real data collection. The primary aim for the code right now is therefore to robustly test it on the mock interviews that are provided by sites and pulled to the development data aggregation server by Lochness. 

##### Pronet <a name="pronet"></a>
This code has been running autonomously on the Pronet development server since early February 2022. Only a minority of sites have correctly added properly formatted interviews to Box and registered the corresponding subject ID in REDCap, but the code has worked well in those cases.

<details>
	<summary>Details on site mock interview status as of 4/25/2022:</summary>

Sites that have successfully had some data processed - 
* PronetLA, PronetYA, PronetNN, and PronetWU have had an interview make it all the way through the pipeline.
	* In the case of PronetYA, three interviews have gone through the pipeline.
	* In the case of PronetLA, two interviews have gone through the pipeline.
	* All other sites with any processing have done a single interview.
* PronetCA, PronetSF, PronetPI, PronetOR, PronetSI, PronetGA, PronetMT, and PronetMA have had transcripts returned by TranscribeMe, but have not yet correctly completed the manual redaction review process.
	* PronetOR, PronetSF, PronetCA, and PronetMT have put the reviewed transcript in the wrong spot on Box.
	* The others don't seem to have attempted to transfer an approved transcript at all.
* PronetPA and PronetTE are currently awaiting transcriptions to be returned by TranscribeMe.

As mentioned there are other sites that have tried to put interviews in Box but there were issues that prevented them from being processed -
* Multiple interviews are unable to be pulled by Lochness to begin with, so they are not available to the code. 
	* PronetIR, PronetKC, and PronetPV all fall into this category due to lack of a correct subject ID registered to REDCap.
* There have also been cases of interviews pulled by Lochness but with naming issues that prevented this code from recognizing them (the files within the Zoom folder should not be renamed by sites!). 
	* PronetHA incorrectly renamed the audio file only, so the video part of the interview has been QCed but the audio has not yet been processed.
	* PronetNC incorrectly renamed all files, so it has not been processed at all.

All sites should have a test interview complete processing, in order to ensure that everyone understands the data collection procedures and has functioning equipment. There are also a few things in particular that really should still be tested - 
* There has not yet been a non-English test audio fully processed.
	* PronetMT, which is a primarily French site (although may use some English) has uploaded a test audio, but has not completed the redaction review portion so that the transcript can finish processing. PronetMA, which is a Spanish site, is now also in the same boat. These are the only non-English sites that have processing in progress.
	* PronetMU (German), PronetPV (Italian), PronetSL (Korean), and PronetSH (Mandarin) are the other non-English Pronet sites. 
	* Testing is especially needed for languages with a very different character set than English.
* No sites have uploaded a test interview under the “psychs” category.
	* These are processed independently from “open” interviews, although the steps are basically the same.
	* The one concern about “psychs” is it can also sometimes involve upload of a single file from an external audio recording device instead of a Zoom interview. The code is written to address this but requires closer testing.
* All sites have uploaded mock interviews that are notably shorter than what we will expect during real data collection. We should test at least one longer interview to ensure there are no compute issues and to get a better sense for expected runtimes and storage requirements.
* Further, to test the "for review" random assignments (and emails) once those are implemented, we will need some sites to upload multiple extra tests.
	* As we verify with TranscribeMe that they are doing all the things we are paying for, we will also want to do additional tests to ensure that when we move to real data TranscribeMe will be following all our instructions regularly. 
* Note that even sites that have been creating subject ID correctly in REDCap have not necessarily been providing a valid mock consent date. It is important in production that sites enter correct consent dates for each subject into REDCap ASAP. 

</details>

Dependencies have been installed on the Pronet production server, but downloading this code and testing there remain to be ironed out. We first need to determine what account should be installing and running the AV pipeline from the production server (after verifying that it has passed the production security review). Then we can discuss remaining required steps. Need to make some decision about how much testing will occur on development server still versus moving to production, and also distinguishing between testing new mock interviews on prod versus actually moving to real data.

As far as real data collection timeline, some sites may be able to begin soon, but others remain months away - need to figure out more about this as summer approaches. There are some deadlines being imposed by NIMH, but it is also not clear how quickly this pipeline needs to launch after data collection starts. There will always be some gap between upload and outputs being available anyway, because of the time it takes to manually transcribe.

##### Prescient <a name="prescient"></a>
We have not yet done any testing of this code on Prescient, but are in the process of coordinating among all relevant parties. The majority of the code should directly translate from Pronet to Prescient, now that Prescient has agreed to use our general file management scheme. Potential issues to address are noted under Next Steps below. We are currently focusing on figuring out how to upload transcripts for review back to Mediaflux, and on creating an SFTP account with TranscribeMe for Prescient (analogous to the one already set up for Pronet).

Note that original mock interviews done by some Prescient sites did not follow the expected SOP, as they were originally using a different plan than Pronet. So sites will need to redo any mock interviews before testing can begin on dev server anyway.  

### Next Steps <a name="todo"></a>
The next steps described here focus on what is necessary to finalize the data flow and quality control workflow for production data collection across sites. Once dataflow and quality control are successfully running, we will then come up with a plan for writing more intensive feature extraction code for the interview datatypes. The feature extraction code will be kept in a separate repository so that it can easily be installed on a separate production machine.

##### Code <a name="code"></a>
<details>
	<summary>The file accounting portions of the code still need to be expanded upon:</summary>

* Maintain a CSV mapping Zoom folder names to renamed audio file names under PROTECTED, so that deletion of WAV files is an option if storage becomes a problem
	* Could something similar be done for the extracted images on the video side as well?
* Add some basic tracking of the existence of speaker-specific audio files
	* Count of different speakers (by Zoom display name)
	* Number of files per speaker (can be split if participant exits and then reenters the Zoom room)
* For the psychs interview type, should make a note of whether interviews are standalone WAV files or full Zoom interviews, so that we know whether other files (video, speaker specific audio) should be expected
* Add some additional checks to help the sites with transfering the "approved" transcripts correctly?
	* Should not pull a transcript back to processed unless it matches one that already exists in prescreening step (can then get rid of extra hard coded checks on study day in the dev server implementation)
	* Confirm with Kevin whether I will need to check for things besides txt files, or if I just need to check on txt file naming. 
* Make the code more robust to revisiting rejected audio or audio that failed to upload to TranscribeMe?
	* This as well as "approved" transcript formatting checks could also be integrated better into email alert system, discussed below

</details>

<details>
	<summary>There are also multiple updates to make to the email alert system:</summary>

* Make necessary tweaks to the existing audio and transcript emails
	* Ensure audio email alert will still send in the case where new audio is processed but none is uploaded to TranscribeMe
	* Detect when audio side code has crashed, preventing full email summary from being generated - that way this case can be handled separately with appropriate notifications sent
	* Review "from" field of emails, particularly where trying to add a reply-to address
* Implement a site-specific email for when file naming issues are detected on the raw side of PHOENIX
	* The email alerts sent by Lochness focus on problems in the source folders, but there are also possible situations where an interview is able to be pulled by Lochness but then can't be processed by this code due to naming issues
	* The logs already note when naming conventions are violated, so would just need to compile this into an email as well
	* The email should probably add a note about consulting with IT to get the bad interview off the server side, because otherwise even once it is fixed by the site the notification will persist due to Lochness not removing files that were deleted on the source
* Add a summary email that compiles complete status to date from across sites
	* Compile a table of raw interviews to basic info about them for each participant and interview type
	* Can include relevant file names, date the raw file was pulled to PHOENIX, date the transcript was returned from TranscribeMe, info on manual site review where needed, and any problems that occured with the interview
	* The script that runs the pipeline across sites that is currently on a cron can then be updated to concatenate all of these tables from all of the sites
	* That will then be emailed to those that are supervising the U24 at a higher level (how to format the table using just basic mailx command?)
	* Need to be careful of PII in these emails? It should be okay to include the dates as long as we are careful about who receives the emails. But keep in mind display names are in the speaker specific Zoom files, that could be much more sensitive (this also applies to the Lochness email alerts!)
	* Will want to consider how this email alert (and others from this pipeline) will integrate with what Lochness is already doing on both the pull and push sides 
* Add an email that notifies sites specifically when there are new transcripts to be reviewed
	* This will go to sites while everything else will just go to central monitoring person(s). Still need the site emails to properly launch this
	* A question to consider when implementing is whether the “for review” emails should go when there are outstanding files, or only when there are updates (as it is now). And should that then also be the case for TranscribeMe emails (which send the entire time one is pending)?
	* Will set this up when I implement the random review portion, see below for more info

For reference, Lochness will alert to a naming problem in raw Box/Mediaflux files based on the following criteria:
* Verify the Subject ID digits ('XX00000' in the folder name) falls into AMP-SCZ ID digits
* 'YYYY-MM-DD HH.MM.SS folder name' – check if the Zoom folder name matches how Zoom creates folder by default
* '.mp4' files have to be under the Zoom directory
* '.m4a' files could be under either the Zoom directory, or below 'Audio Record'

Similarly, for transcripts in the "approved" folder, it will ensure they are .txt files found under a subject ID subfolder.

</details>

<details>
	<summary>Finally, there are a few features that remain to be added:</summary>

* Implement the transcript manual review as a random selection of 10% of transcripts per site instead of sending all transcripts for additional review
	* This phase will occur once a given site has had 5 transcripts reviewed - so need to keep the current code as well, have an appropriate toggle
	* Can use the "completed" folder under box_transfers to track how many transcripts have already been pushed for review to the sites
	* For the actual random selection, should be fine to just use a random number generator to get a 10% chance independently for each file
	* May also want to add a check for 0 redactions to always be sent for site review, just in case something goes wrong with the foreign language encodings while I'm away. I doubt we will ever encounter 0 redactions in a correctly transcribed real interview. Note this could also be part of email alert to sites!
	* Once it is implemented, also need to make sure that the status emails and other file accounting pieces of the pipeline are updated to appropriately reflect
* Improve how code processes non-English transcripts
	* Switch check for required encoding to UTF-8 instead of ASCII (should also probably note what the encoding is in a file accounting output?)
	* Update transcript QC code so features are correct in every language (requires some more information from TranscribeMe in part)
	* Should also make sure that Zoom file naming conventions are not substantially different in different countries!
	* In general could improve how code handles random unexpected characters when they are inserted by TranscribeMe?
* Add preprocessing for Teams and WebEx interviews to accommodate the couple of Prescient sites that cannot use Zoom
	* Waiting on examples of interviews from these softwares first
	* Which sites are they? There has been some turnover in included sites, so it is possible some of these edge cases are no longer relevant or that new edge cases have been introduced
* Handle local video feature extraction where needed
	* Jena is not allowed to have video uploaded to the aggregation server, although they can have the audio uploaded
	* Awaiting contact from Jena point person about how to set up some code to handle the video portion (and related file organization) locally
	* For now Jena has been provided with a high level plan and security information, which it seems will be sufficient to move forward with
* Perhaps add video duration, resolution, and fps to the video QC to supplement the image-based/face-related features?
* Make a DPDash summary of QC features CSV as part of the pipeline slightly down the road? 
	* Would be nice to see an overview of the QC stats to have a better grounding in what an individual value means
	* This could play into the summary email that I am supposed to be making anyway too
	* Need to be more familiar with how DPDash works first though - Where would the CSV even be saved? Would it be one per site or one overall or potentially both? What columns matter? 

</details>

Once the above TODOs are done, a full code review should be performed to ensure everything is well documented and no unnecessary pieces of old code remain. Could also make note of possible future efficiency improvements at that time.

##### Logistics <a name="logistics"></a>
For the existing protocols, it is an ongoing issue to ensure that sites are aware of and following all the expectations. 

<details>
	<summary>There are also some details that need to be verified on our end still in order to make some final decisions about the code:</summary>

* Most urgently, we need to determine what is the final decision about use of consent dates in the code
	* If data will be able to be pulled in production without a valid consent date, I should confirm what the dummy consent date is and then stop this code from doing any processing for any subject that has such a consent. However there is also a chance Lochness won't pull without a valid consent date, in which case I can just leave as is
	* Note default on dev server is now 10/01/2021, allowing this to be used for testing purposes but will not worry about if the date changes and study alignment no longer makes sense for the mock interviews
	* Should still probably add some tracking of consent date into file accounting so issue can be easily noticed if for some reason a subject's consent date does change part way through
* Need to review redaction guidelines with TranscribeMe and ensure they are not being over the top aggressive with redaction (but also careful not to miss anything that is obvious PII)
* Need to confirm TranscribeMe is switching to millisecond resolution on the transcript timestamps
	* Note that this also requires them to actually give us sentence level timestamps! Make sure they are not cheaping out on the definition of a sentence
	* More generally, we should be on same page about all expectations and the protocol for when mistakes happen, before moving into production
* Also still waiting on TranscribeMe to answer about the verbatim transcription conventions in other languages. Need to confirm what will be different (at the very least I would expect markings like "inaudible" to be different)
	* Even for English, TranscribeMe has sometimes been inconsistent with the exact characters that they use for dashes and other things important to represent in the verbatim style transcriptions - although they have confirmed they are working on refining their processes to minimize these issues in the future. 
	* Consider writing more detailed documentation about TranscribeMe when wrapping up this project?
* How will we identify from the speaker specific audio file names which audio belongs to the participant? Interviewers could keep a consistent display name or sites could provide a list of all interviewer display names used perhaps. Regardless, this will be another issue for file accounting code to check once a method is decided on
* How do we want to identify which TranscribeMe speaker ID is the participant? Should we have some convention like always having the interviewer say some particular word at the start, or can we tackle the problem with purely automated methods? Or perhaps the transcriber could intentionally use a particular ID for who they think the participant is?

TranscribeMe has been notified about the various issues above related to them, but addressing it remains ongoing.

</details>

<details>
	<summary>Before we can launch, many questions still remain about code monitoring and communication with various relevant parties as well. The main TODOs there are:</summary>

* Make decisions about email usage
	* Does content of any of the emails need to be further updated?
	* Who should receive which emails? 
	* How often should emails go out?
	* Any PII concerns with the emails to address?
* Make decisions about code monitoring
	* What account is going to run the code?
	* Ensure file permissions generated by Lochness are compatible, particularly for the processed folders under both PROTECTED and GENERAL
	* What should file permissions be of various code outputs?
	* How often should the code run?
	* Who will handle it when changes need to be made on the server? Could involve changes to code, changes to files in processed folders, or changes to files in raw folders
	* Who will be checking the QC outputs on DPDash?
* Finish actually setting up DPDash
	* Make sure audio, transcript, and video CSVs are being imported (for DPDash dev server paths are at /data/predict/kcho/flow_test/Pronet/PHOENIX/GENERAL/\*/processed/\*/interviews/\*/\*QC\*.csv) - this should be in progress, awaiting additional info from Tashrif
	* Decide which features we want to display from each
	* Create config files on the UI and ensure colormap bounds make sense for each feature shown
	* First config for looking at core audio, video, and transcript QC features together has been drafted, but need to split it out into more detailed configs for each modality individually instead. Can then also further refine boundaries, color scheme, etc. Note these need to be done for both open and psychs interviews separately due to our folder structure
* Set protocol for communication with sites
	* What happens when sites have mistakes with file naming/organization conventions?
	* What happens when sites are missing data or don't complete a necessary manual review?
	* What happens when sites upload poor quality data?
	* Who will be in charge of all of this?
* Set protocol for communication with TranscribeMe (this can also be discussed at 4/4 meeting with TranscribeMe reps!)
	* On both sides, who will be receiving any automated communication about SFTP uploads?
	* What happens when TranscribeMe does not upload a transcript we are expecting for an extended period?
	* What happens when a transcript has enough issues that it needs to be redone?
	* What happens when there is a minor issue in a transcript (outside of the already defined site redaction review)?
	* Will we be providing TranscribeMe with continual feedback?
	* Who will be in charge of all of this?
	* What if an issue arises that requires a speaker of a non-English language?
* Will these communication protocols need to differ between the Pronet and Prescient networks?

Should ensure everyone is aware Michaela will be away for the summer (late May through mid August).

</details>

Finally, there are a few logistics to handle specific to Pronet and Prescient. For Pronet, we just need to take the last steps for setup of the production server. This involves confirming that the latest version of the code with the new video QC features is installed, verifying that this code passed the Yale IT security review, and performing an actual test run on prod. Should be cognizant of available compute resources on the production server while testing, as dev server could easily run out of RAM, and production interviews will be a bit longer than the mock interviews.

<details>
	<summary>For Prescient, there are many more steps, as we still need to get the development server installation working first before proceeding to production setup. The major blockers we are actively trying to address for this are:</summary>

* Completing code security review, as we may require approval to install the code even on the dev server
	* We seem to now have initial approval to at least test on dev, but should confirm this (and make sure I have an account with the necessary permissions on that server)
* Figure out how the code will integrate with Mediaflux instead of Box
	* Prescient team is currently communicating with Mediaflux about how this will work, but we should be okay to use same general architecture as we do for Pronet
	* For the actual push operation back to Mediaflux, should be able to use SFTP
	* We will likely have to implement this piece for Prescient even though it was implemented by Yale IT for Pronet
	* [Next step is to review the Mediaflux SFTP documentation, follow-up with any remaining questions](https://wiki-rcs.unimelb.edu.au/pages/viewpage.action?pageId=328435)
	* Will add implementation plan here once determined
* Get a TranscribeMe SFTP account appropriately set up
	* TranscribeMe has sent Kate information on how to do this, awaiting word from her on the account details
* Compile a table of the languages that will be used at the different sites 

Our current primary focus is establishing the necessary connection with TranscribeMe. The next focus will be on interfacing with Mediaflux. 

It also happens that most of the sites with special cases to handle are part of the Prescient network, and accommodating these cases is part of the code TODOs noted above. However, we will be prioritizing getting the standardized code working on Prescient first. 

</details>

When finalizing documentation for this repository, may want to rename it to ensure it better reflects the purpose of this code - running data aggregation/organization and quality control operations for interviews for the multisite AMP-SCZ study, and appropriately communicating the results of these operations. 

At that time should also make sure example screenshots, setup instructions, etc. are fully up to date
