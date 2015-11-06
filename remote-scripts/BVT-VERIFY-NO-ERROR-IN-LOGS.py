#!/usr/bin/python

from azuremodules import *


import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument('-wl', '--whitelist', help='specify the xml file which contains the ignorable errors')

args = parser.parse_args()
white_list_xml = args.whitelist

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking for ERROR messages in waagent.log...")
    errors = Run("grep -i error /var/log/waagent.log")
    if (not errors) :
        RunLog.info('There is no errors in the logs waagent.log')
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        if white_list_xml and os.path.isfile(white_list_xml):
            try:
                import xml.etree.cElementTree as ET
            except ImportError:
                import xml.etree.ElementTree as ET

            white_list_file = ET.parse(white_list_xml)
            xml_root = white_list_file.getroot()
            RunLog.info('Checking ignorable walalog ERROR messages...')
            for node in xml_root:
                if (errors and node.tag == "errors"):
                    errors = RemoveIgnorableMessages(errors, node)
        if (errors):
            RunLog.info('ERROR are  present in wala log.')
            RunLog.info('Errors: ' + ''.join(errors))
            ResultLog.error('FAIL')
        else:
            ResultLog.info('PASS')
        UpdateState("TestCompleted")
		
def RemoveIgnorableMessages(messages, keywords_xml_node):
    message_list = messages.strip().split('\n')
    valid_list = []
    for msg in message_list:
        for keywords in keywords_xml_node:
            if keywords.text in msg:
                RunLog.info('Ignorable ERROR message: ' + msg)
                break 
        else:
            valid_list.append(msg)
    if len(valid_list) > 0:
        return valid_list
    else:
        return None                

RunTest()