#!/usr/bin/python

import argparse
import sys
import dns.resolver

parser = argparse.ArgumentParser()

parser.add_argument('-n', '--hostname', help='hostname or fqdn', required=True)
args = parser.parse_args()

n = args.hostname
try:
	while true:
		for rdata in dns.resolver.query(n, 'CNAME'):
			n = rdata.target
except:
	for rdata in dns.resolver.query(n):
		print rdata