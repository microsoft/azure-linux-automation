#!/usr/bin/env python

from azuremodules import *
from argparse import ArgumentParser
import time
import commands
import signal
import platform

parser = ArgumentParser()
parser.add_argument('-d', '--duration', help='specify how long run time(seconds) for the stress testing', required=True, type=int)
parser.add_argument('-p', '--package', help='spcecify package name to keep downloading from RHUI repo', required=True)
parser.add_argument('-t', '--timeout', help='specify the base value(seconds) to evaluate elapsed time of downloading package every time', required=True, type=int)
parser.add_argument('-s', '--save', help='save test data to log file', required=False, action='store_true')

args = parser.parse_args()
duration = args.duration
pkg = args.package
timeout = args.timeout

pkg_download_path = "/tmp/rhui_stress"

class RunlogWrapper:
	def __init__(self):
		pass
	def info(self,msg):
		RunLog.info(msg)
		print(msg)
	def error(self,msg):
		RunLog.error(msg)
		print(msg)
		
class MyTimeoutException(Exception):
	pass

logger = RunlogWrapper()

def DetectDist():
	return platform.linux_distribution()

def RunTest():
	UpdateState("TestRunning")
	logger.info('-'*30 + str.format("RHUI STRESS TEST START FOR %s %s" % DetectDist()[0:2]) + '-'*30)
	logger.info('Test Infomation:')
	logger.info("\tTest package: %s, Test duration: %s(seconds), Test base value: %s(seconds)" % (pkg, duration, timeout))
	RunLog.info('')

	download_details = []

	# cleanup before kickoff
	CleanUp()
	counter = 1
	start_time = time.time()
	# todo: if need to clean cache here
	while (time.time() - start_time) < duration:
		RigsterSigHandler(timeout)
		download_details.append(DownloadPkg(pkg, pkg_download_path, counter))
		UnrigsterSigHandler()
		CleanUp()
		print('Test Round #%s is finished.' % counter)
		counter += 1

	UpdateState("TestCompleted")
	AnalyseResult(download_details)

	if args.save:
		t = time.localtime()
		ts = "%d%02d%02d%02d%02d%02d" % (t.tm_year,t.tm_mon,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec)
		log_dl = str.format('download-%s.log' % ts)
		with open(log_dl,'w') as f:
			f.write("%s %s\n" % DetectDist()[0:2])
			for i in iter(download_details):
				f.write(str(i[0])+'\t'+str(i[1])+'\n')
		logger.info('Saved download test details to %s' % log_dl)

	logger.info('-'*30 + 'RHUI STRESS TEST END' + '-'*30 )

def SigHandler(signum, frame):
	raise MyTimeoutException('operation timeout!')

def RigsterSigHandler(t):
	signal.signal(signal.SIGALRM, SigHandler)
	signal.alarm(t)

def UnrigsterSigHandler():
	signal.alarm(0)

def DownloadPkg(pkg, download_path, counter):
	cmd = 'yum install %s -y --downloadonly --downloaddir=%s' % (pkg, download_path)
	rst = None
	elapsed = None
	RunLog.info('[%s][#%s] >>>>>>>>> %s' % ('DOWNLOAD',counter,pkg))
	st = time.time()
	try:
		rtc, out = commands.getstatusoutput(cmd)
	except MyTimeoutException as err:
		elapsed = time.time() - st
		rst = "timeout"
		RunLog.error('\tTIMEOUT!!!')
	else:
		elapsed = time.time() - st
		if int(rtc) == 0:
			rst = 'success'
			RunLog.info('\tSUCCESS in %s seconds!' % str(elapsed))
		else:
			rst = 'fail'
			RunLog.error('\tFAIL with error: %s!' % out)
	finally:
		return (rst, elapsed)

def RemoveDownload():
	JustRun('rm -rf %s' % pkg_download_path)
	RunLog.info('Downloaded packages removed.')

def CleanYumCache():
	out = JustRun('yum clean all')
	if 'Cleaning up everything' in out.split('\n') or 'Cleaning up Everything' in out.split('\n'):
		RunLog.info('yum cache cleanup.')
	else:
		RunLog.error('yum cache cleanup failed.')

def CleanUp():
	RemoveDownload()
	CleanYumCache()
	RunLog.info('Test cleanup done.')

def AnalyseResult(l_download):
	success_download_count, fail_download_count, timeout_download_count = 0,0,0

	try:
		if len(l_download) != 0 :
			for i in iter(l_download):
				if i[0] == 'success':
					success_download_count += 1
				elif i[0] == 'fail':
					fail_download_count += 1
				else:
					timeout_download_count += 1
			
			cost_of_valid_download = [x[1] for x in iter(l_download) if x[0] == 'success']

			# summary
			logger.info('-'*30 + "SUMMARY" + '-'*30)
			logger.info('Total Download: %s, Success: %s, Fail: %s, Timeout: %s' % (len(l_download),success_download_count,fail_download_count,timeout_download_count))
			if len(cost_of_valid_download):
				logger.info('\tThe fastest download in %s seconds' % min(cost_of_valid_download))
				logger.info('\tThe slowest download in %s seconds' % max(cost_of_valid_download))
				logger.info('\tThe average download in %s seconds' % str(sum(cost_of_valid_download)/len(cost_of_valid_download)))
			else:
				logger.error('\tNone valid download!!!')
				
			if fail_download_count == 0 and timeout_download_count == 0:
				ResultLog.info('PASS')
			else:
				ResultLog.error('FAIL')
	except Exception as err:
		print(err)

RunTest()