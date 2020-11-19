#!/usr/bin/python3
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import smtplib
import sys
import os
#import base64

# Server details
debuglevel   = 0
server_host  = 'mail.server.tld'
server_port  = 587
server_user  = 'user@emailk.tld'
server_pass  = 'password'
mail_subject = sys.argv[1]

# Build Message
msg = MIMEMultipart()
msg['From'] = server_user
msg['To'] = "to@email.tld"
msg['Subject'] = sys.argv[1]

# Add text from File
filename = os.path.abspath(sys.argv[2])
fo = open(filename, 'r')
filecontent = fo.read()
body = (filecontent)
fo.close
msg.attach(MIMEText(body, 'plain'))

# Send
server = smtplib.SMTP(server_host, server_port)
server.starttls()
server.login(server_user, server_pass)
server.sendmail(msg['From'], msg['To'], msg.as_string())
server.quit()
