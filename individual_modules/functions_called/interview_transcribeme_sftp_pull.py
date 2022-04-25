#!/usr/bin/env python

import pysftp
import os
import sys

# make sure if paramiko throws an error it will get mentioned in log files
import logging
logging.basicConfig()

def transcript_pull(interview_type, data_root, study, ptID, username, password, transcription_language, pipeline=False, lab_email_path=None):
	# track transcripts that got properly pulled this time, for use in cleaning up server later
	successful_transcripts = []

	# hardcode the basic properties for the transcription service, password is only sftp-related input for now
	source_directory = "output" # need to ensure transcribeme is actually putting .txt files into the top level output directory as they are done, consistently!
	host = "sftp.transcribeme.com"

	try:
		directory = os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type, "pending_audio")
		os.chdir(directory) 
	except:
		# no files for this patient then
		return

	# loop through files in pending, trying to pull corresponding txt files that are in the transcribeme output folder
	cur_pending = os.listdir(".")
	if len(cur_pending) == 0:
		# no files for this patient
		return

	print("Pulling new " + interview_type + " transcripts to server for participant " + ptID + " (if available)")
	
	for filename in cur_pending:
		# setup expected source filepath and desired destination filepath
		rootname = filename.split(".")[0]
		transname = rootname + ".txt"
		transname_lookup = rootname.split("session")[0] + transcription_language + "_session" + rootname.split("session")[1] + ".txt"
		src_path = os.path.join(source_directory, transname_lookup)
		# for now put all pulled transcripts into the prescreening folder. eventually that will change though, will need to be random process for sites that have completed initial reviews
		local_path = os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type, "transcripts", "prescreening", transname)
		# now actually attempt the pull. will hit the except in all cases where the transcript isn't available yet, but don't want that to crash rest of code obviously
		try:
			cnopts = pysftp.CnOpts()
			cnopts.hostkeys = None # ignore hostkey
			with pysftp.Connection(host, username=username, password=password, cnopts=cnopts) as sftp:
				sftp.get(src_path, local_path)
			successful_transcripts.append(transname_lookup) # if we reach this line it means transcript has been successfully pulled onto PHOENIX
			# this audio is no longer pending then, decrypted copy should be deleted from briefcase
			if pipeline:
				pending_rename = "done+" + filename # + not used in transcript names, so will make it easy to separate prepended info back out
				os.rename(filename,pending_rename) # if part of pipeline will just temporarily rename with prepended code, parent script will use this to generate email and then move
		except:
			# nothing to do here, most likely need to just keep waiting on this transcript
			# in future could look into detecting types of connection errors, perhaps not always assuming a miss means not transcribed yet
			# even the current email alerts should make other issues easy to catch over time though, so not a big priority
			try:
				# seems this sometimes creates an empty file at the prescreening path, so just remove that for clarity
				os.remove(local_path)
			except:
				pass 

	# log some very basic info about success of script
	print("(" + str(len(successful_transcripts)) + " total transcripts pulled)")

	# now do cleanup on trancribeme server for those transcripts successfully pulled
	input_directory = "audio"
	prev_problem = False # for preventing repetitive warning going into the email
	for transcript in successful_transcripts:
		# will remove decrypted audio from TranscribeMe's server, as they do not need it anymore
		match_name = transcript.split(".")[0] 
		match_audio = match_name + ".wav"
		remove_path = os.path.join(input_directory, match_audio)
		# will also move the pulled transcript into an archive subfolder of output on their server (organized by study)
		cur_path = os.path.join(source_directory, transcript)
		archive_name = study + "_archive"
		archive_path = os.path.join(source_directory, archive_name, transcript)
		archive_folder = os.path.join(source_directory, archive_name) # also need just the folder path so it can be made if doesn't exist yet
		# actually connect to server to do the updates for current transcript
		# (note it hasn't been a problem previously to establish new connection each time - 
		#  but in future may want to refactor so only need to establish connection once per patient instead of per file)
		try:
			cnopts = pysftp.CnOpts()
			cnopts.hostkeys = None # ignore hostkey
			with pysftp.Connection(host, username=username, password=password, cnopts=cnopts) as sftp:
				sftp.remove(remove_path) 
				if not sftp.exists(archive_folder):
					sftp.mkdir(archive_folder)
				sftp.rename(cur_path, archive_path)
		except:
			# expect failures here to be rare (if generic connection problems successful_transcripts would likely be empty)
			print("Error cleaning up TranscribeMe server, please check on file " + match_name)
			# also add a related warning in this patient's section of email file if this was called via pipeline - but just make it a generic one liner
			if pipeline and not prev_problem:
				with open(lab_email_path, 'a') as f:
					# not a particularly urgent problem, but could go unnoticed for a long time if not notified, and best practice is to minimize number of copies/locations with decrypted audio
					warning_text = "[May have encountered a problem cleaning up completed audios for " + OLID + " on TranscribeMe server, please review manually]"
					f.write("\n") # add a blank line before the warning
					f.write(warning_text)
					f.write("\n") # and add a blank line after

				prev_problem = True # now that it's been added no need to add again if another problem arises

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	try:
		if sys.argv[8] == "Y":
			# if called from main pipeline want to just rename the pulled files in pending_audio here, so email script can use it before deletion
			transcript_pull(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], pipeline=True, lab_email_path=sys.argv[9])
			# should always expect a 5th argument if here, as that means coming from pipeline. otherwise no need to even enter the lab_email_path setting
		else:
			# otherwise just deleting the audio immediately
			transcript_pull(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
	except:
		# if pipeline argument never even provided just want to ignore, not crash
		transcript_pull(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
    