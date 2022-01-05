#!/usr/bin/env python

import os
import sys

# helper function takes path (filename) to raw transcript txt file and saves a new copy with PII redacted at savepath
# relies on PII marked within curly brackets. each instance of curly brackets will have all words within (separated on spaces) replaced with "REDACTED"
# assumes that after each { a } will follow before another {, that an unmatched bracket (or an empty set of braces) will not occur, and there will be some character between any } and {. 
# this matches the TranscribeMe convention for marking PII. also, because of subject IDs/timestamps we know a line will never begin with a {. it plausibly could end with a } though
def redact_transcript(filename, savepath):
	# do argument sanity check first
	# if calling via pipeline, shouldn't hit these messages
	if not os.path.isfile(filename):
		print("Input transcript path is not a file (" + filename + "), skipping")
		return
	if os.path.exists(savepath):
		print("Intended output path already exists (" + savepath + "), skipping")
		return

	# get a list of the lines in the input transcript txt file
	with open(filename, 'r') as input_file: # read mode
		input_lines = input_file.readlines()
		# remove white space characters from the ends of the lines for cleaning
		input_lines = [line.rstrip() for line in input_lines]

	# now go line by line through the input and write a modified version to the output file
	output_file = open(savepath, 'w') # write mode
	for line in input_lines:
		pre_redact_list = line.split("{")
		if len(pre_redact_list) == 1: # if no redaction at all in this line write it as is and continue
			output_file.write(pre_redact_list[0])
			continue
		# handle anything that comes before the first redaction, start string that will be written to new file for this line
		modified_line = pre_redact_list[0] + "{"

		# now start going through the redactions
		for contents in pre_redact_list[1:-1]: # exclude very last brace in a given line here, as it may end the line and needs to be treated slightly differently
			cur_post_redact_list = contents.split("}")
			# expect each of these items to have a single } with meaningful content both before and after
			if len(cur_post_redact_list) != 2:
				print("Redaction convention violated in file (" + filename + "), please review manually")
				output_file.close()
				os.remove(savepath) # delete it as a protection for accidentally putting PII in general
				return
			# the content before is what needs to be redacted, the content after can be kept as is
			# find how many words occur inside the curly brace by splitting the first part by spaces
			to_redact = len(cur_post_redact_list[0].split(" "))
			for word in range(to_redact-1):
				modified_line = modified_line + "REDACTED "
			modified_line = modified_line + "REDACTED}" # assume there will always be at least one word inside the braces! could add more safety checks here?
			# now add the normal content back, plus the front curly brace as we know we are not on the last one yet if in this loop
			modified_line = modified_line + cur_post_redact_list[1] + "{"
		
		# now just handle final redaction in the line
		final_redaction = pre_redact_list[-1]
		if final_redaction[-1] == '}': # handle case where the last character is a curly brace ender separately
			# here just need to add the redaction, not any subsequent text. do that part as before
			to_redact = len(final_redaction.split(" "))
			for word in range(to_redact-1):
				modified_line = modified_line + "REDACTED "
			modified_line = modified_line + "REDACTED}"
		else: # when there is content after the final redaction, handle similarly as before, just don't add an extra {
			cur_post_redact_list = final_redaction.split("}")
			# expect each of these items to have a single } with meaningful content both before and after
			if len(cur_post_redact_list) != 2:
				print("Redaction convention violated in file (" + filename + "), please review manually")
				output_file.close()
				os.remove(savepath) # delete it as a protection for accidentally putting PII in general
				return
			# the content before is what needs to be redacted, the content after can be kept as is
			# find how many words occur inside the curly brace by splitting the first part by spaces
			to_redact = len(cur_post_redact_list[0].split(" "))
			for word in range(to_redact-1):
				modified_line = modified_line + "REDACTED "
			modified_line = modified_line + "REDACTED}" # assume there will always be at least one word inside the braces! could add more safety checks here?
			# now add the normal content back
			modified_line = modified_line + cur_post_redact_list[1]
		
		# finally can write the new line that was put together
		output_file.write(modified_line)
		output_file.write("\n") # add a new line after each line is written! good for reading in txt file, csv conversion script will strip
	
	# done going through the transcript, can close the file and return
	output_file.close()
	return

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	redact_transcript(sys.argv[1], sys.argv[2])
