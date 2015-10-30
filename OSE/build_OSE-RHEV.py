#!/usr/bin/env python

from ovirtsdk.api import API
from ovirtsdk.xml import params
import os.path

RHEVM="rh6rhevmgr"
DOMAIN="matrix.lab"

URL      = "https://${RHEVM}.${DOMAIN}/api"
USERNAME = "admin@internal"
PASSWORD = "Passw0rd"
CA_FILE  = "/etc/pki/ovirt-engine/ca.pem"

api = API(url=URL, username=USERNAME, password=PASSWORD, ca_file=CA_FILE)

# Make sure we have the cert to the RHEV Manager API
if ( not os.path.isfile(CA_FILE)):
  print ("Error: %s file not found" % CA_FILE)
else:
  print ("SUCCESS: %s file found" % CA_FILE)
